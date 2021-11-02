require 'puppet/type/file'
require 'puppet/util/checksums'

begin
  require_relative '../../puppet_x/vox_pupuli/xmlfile/lens
rescue
  require 'pathname'
  mod = Puppet::Module.find('xmlfile', Puppet[:environment].to_s)
  raise LoadError('Unable to find xmlfile module in module path') unless mod
  require File.join(mod.path, 'lib', 'puppet_x', 'vox_pupuli', 'lens')
end

# Equivalent to the file resource in every way but how it handles content.
Puppet::Type.newtype(:xmlfile) do
  @doc = <<-'EOT'
    Previously an extension of the base file resource type, now a partial reimplementation with the
    deprecation of :parent.  An xmlfile behaves like a file in all ways
    except that its content can be modified via xmlfile_modification resources.

    This enables the mixing of exported or virtual content and
    templated or static content, while managing the end-result as a single resource.

    The following attributes are inherited from the file type:
    - ctime (read-only)
    - group
    - mode
    - path
    - mtime (read-only)
    - owner
    - selinux_ignore_defaults
    - selrange
    - selrole
    - seltype
    - seluser
    - source
    See: http://docs.puppetlabs.com/references/latest/type.html#file for details
  EOT

  # Ignore rather than include in case the base class is messed with.
  # Note that the parameters defined locally don't actually exist yet until this block is evaluated so to
  # act based on that kind of introspection you would need to move all of this into another file
  # that gets required after this block.
  IGNORED_PARAMETERS = [:backup, :recurse, :recurselimit, :force,
                        :ignore, :links, :purge, :sourceselect, :show_diff,
                        :provider, :checksum, :type, :replace, :path].freeze
  IGNORED_PROPERTIES = [:ensure, :target, :content].freeze

  # Finish up extending the File type - define parameters and properties
  # that aren't ignored and aren't otherwise defined.

  # Parameters - appear to require a lookup
  Puppet::Type::File.parameters.each do |inherit|
    next if IGNORED_PARAMETERS.include?(inherit)
    begin
      klass = Puppet::Type::File.const_get("Parameter#{inherit.to_s.capitalize}")
      newparam(inherit, parent: klass) do
        desc klass.doc
      end
    rescue StandardError => err
      warning err.to_s
      warning "Inheritance assumption case problem: #{klass} undefined but not ignored"
    end
  end

  # Properties are easier as the class is in the instance variable
  Puppet::Type::File.properties.each do |inherit|
    next if IGNORED_PROPERTIES.include?(inherit.name)
    newproperty(inherit.name.to_sym, parent: inherit) do
      desc inherit.doc
    end
  end

  # Need to override the following two functions in order to
  # ignore recurse and backup parameters
  def bucket        # to ignore :backup
    nil
  end

  def eval_generate # to ignore :recurse
    []
  end

  # Now code lifted directly from puppet because we can't use :parent anymore
  # Had to be stolen from File because :parent was deprecated
  # this means all code is now under ASL ( frowny face)
  newparam(:path) do
    desc <<-'EOT'
      The path to the file to manage. Must be fully qualified.

      On Windows, the path should include the drive letter and should use `/` as
      the separator character (rather than `\\`).
    EOT
    isnamevar

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise Puppet::Error, "File paths must be fully qualified, not '#{value}'"
      end
    end

    munge do |value|
      if value.start_with?('//') && ::File.basename(value) == '/'
        # This is a UNC path pointing to a share, so don't add a trailing slash
        ::File.expand_path(value)
      else
        ::File.join(::File.split(::File.expand_path(value)))
      end
    end
  end

  def exist?
    stat ? true : false
  end

  def stat
    return @stat unless @stat == :needs_stat

    method = :stat

    @stat = begin
      Puppet::FileSystem.send(method, self[:path])
    rescue Errno::ENOENT
      nil
    rescue Errno::ENOTDIR
      nil
    rescue Errno::EACCES
      warning 'Could not stat; permission denied'
      nil
    end
  end

  def property_fix
    properties.each do |thing|
      next unless [:mode, :owner, :group, :seluser, :selrole, :seltype, :selrange].include?(thing.name)

      # Make sure we get a new stat objct
      @stat = :needs_stat
      currentvalue = thing.retrieve
      thing.sync unless thing.safe_insync?(currentvalue)
    end
  end

  # Now our code starts
  ensurable

  # Actual file content
  newproperty(:content) do
    desc <<-'EOT'
      The desired contents of a file, as a string. This attribute is mutually
      exclusive with `source`.
    EOT
    include Puppet::Util::Checksums

    # Convert the current value into a checksum so we don't pollute the logs
    def is_to_s(value) # rubocop:disable Style/PredicateName
      md5(value)
    end

    # Convert what the value should be into a checksum so we don't pollute the logs
    def should_to_s(value)
      md5(value)
    end
  end

  newparam(:raw) do
    desc <<-'EOT'
      The desired formatting of the content after being passed through the REXML lens.
    EOT

    defaultto true
  end

  # Formatting:  In case you want REXML to pretty things up.
  newparam(:format) do
    desc <<-'EOT'
      The desired formatting of the content after being passed through the REXML lens.
    EOT

    validate do |value|
    end
  end

  # Generates content
  def should_content # Ape the name from property::should
    return @should_content if @should_content # Only do this ONCE
    @should_content = ''

    # Get our base content
    # Need to retrieve and render our current content
    content = if !self[:content].nil?
                self[:content]
              elsif !self[:source].nil?
                Puppet::FileServing::Content.indirection.find(self[:source], environment: catalog.environment).content
              else
                '' # No content so we start with a base string.
              end
    # Wrap it in a REXML::Document

    xml_content = if self[:raw] == true
                    REXML::Document.new(content, raw: :all)
                  else
                    REXML::Document.new(content)
                  end

    # Need to order this by requirements.  I *think* puppet does this in the catalog, but I'm not positive.
    res = catalog.resources.select do |resource|
      resource.is_a?(Puppet::Type.type(:xmlfile_modification)) && resource[:file] == (self[:path])
    end

    res.each do |resource|
      process = XmlLens.new(xml_content, resource[:changes], resource[:onlyif])
      xml_content = process.evaluate
    end

    # Write the final xml into the instance var.
    xml_content.write(@should_content)

    @should_content
  end

  # Make sure we only set source or content, but not both.
  validate do
    if self[:source] && self[:content]
      raise(Puppet::Error, 'Can specify either source or content but not both.')
    end
  end
end
