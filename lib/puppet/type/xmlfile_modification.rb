# frozen_string_literal: true

require 'puppet/type/file' # Let us use file validations

# No provider for this so it should ultimately just be data
Puppet::Type.newtype(:xmlfile_modification) do
  @doc = <<-'EOT'
    Apply a change or an array of changes constrained by conditionals, to a specified xml file
    using syntax similar to the augeas XML lens.  Changes are applied in memory
    during content generation when the catalog is applied.

    Requires:

    - REXML

    Sample usage with strings:

        xmlfile_modification{"test" :
          file    => "/etc/activemq/activemq.conf.xml",
          changes => "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/name \"test\"",
          onlyif  => "match /beans/broker/transportConnectors/transportConnector[#attribute/name == \"test\"] size < 1",
        }

    Sample usage with arrays:

        xmlfile_modification{"test" :
          file    => "/etc/activemq/activemq.conf.xml",
          changes => [ "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/name \"tests\"",
                       "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/value \"tests\""],
          onlyif =>  [ "match /beans/broker/transportConnectors/transportConnector[#attribute/name == \"tests\"] size < 1" ],
        }

  EOT

  # Need to figure out if I can autoset this.
  newparam(:name) do
    desc 'Name to use to identify this modification.  Must be unique.'
    isnamevar
  end

  newparam(:changes) do
    desc <<-EOT
    Changes which should be applied to the file.  Can be a command or an array of commands.  Augeas-esque syntax.

    Paths are XPATHs. Attributes are matched via #attribute/<ATTR>, or assumed to be text.  Evaluations must be bracketed.

    Commands:

    - add <PATH>
    : Adds an empty node at path(always creates last element, rest as needed)

    - set <PATH> "<VALUE>"
    : Sets the path to value, creates it if it does not exist

    - rm <PATH>
    : Removes the path.

    - remove
    : Alias for rm.

    - clear <PATH>
    : Clears the specied path.  Does not create it.

    - ins <PATH> (before|after) <LOCATION>
    : Constructs an element(or elements) using path and inserts it before or after the path specified by location

    - insert
    : Alias for ins

    - sort <PATH> (<VALUE>|text)
    : Sorts all elements that match path by the attribute specified in value(or by element name if nothing specified).

    Path Functions:

    - last()
    : During initial parsing, substitutes for the index of the last item that matches the expression.

    EOT
    defaultto []

    validate do |value|
      case value.class.to_s
      when 'Array'
        value.each do |val|
          resource.validate_command(val)
        end
      when 'String'
        resource.validate_command(value)
      else
        raise(Puppet::Error, 'Changes must be passed as an array or string')
      end
    end
  end

  newparam(:onlyif) do
    desc <<-EOT
    Constrains application of changes via conditionals.  Augeas-esque syntax.

    Paths are XPATHs.  Attributes are matched via #attribute/<ATTR>, or assumed to be text.  Evaluations must be bracketed.

    Commands:

    - match <PATH> size (==|!=|<|>|<=|>=) <VALUE>
    : Evaluates if a match for the given path meets the conditions specified.

    - get <PATH> (==|!=|<|>|<=|>=) <VALUE>
    : Checks if a path matches a given value under the conditions specified

    Path Functions:

    - last()
    : During initial parsing, substitutes for the index of the last item that matches the expression.

    EOT
    defaultto []

    validate do |value|
      case value.class.to_s
      when 'Array'
        value.each do |val|
          resource.validate_command(val)
        end
      when 'String'
        resource.validate_command(value)
      else
        raise(Puppet::Error, 'Changes must be passed as an array or string')
      end
    end
  end

  newparam(:file) do
    desc 'The path of the xmlfile to work with.'
    isrequired
    validate do |value|
      # raise(Puppet::Error, "Invalid filename '#{value.inspect}'") unless value and value != ""
      raise Puppet::Error, "File paths must be fully qualified, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end

  # Autorequire the xmlfile resource
  autorequire(:xmlfile) do
    self[:file]
  end

  # Validations.
  def validate_command(value)
    parse = value.match(%r{^(\S+)\ (.*)$})
    raise(Puppet::Error, 'Must pass a command') unless parse

    case parse[1]
    when 'clear'
      validate_path(parse[2])
    when 'set'
      args = parse[2].match(%r{(.*)\ "(.*)"$})
      raise(Puppet::Error, 'Invalid syntax for set command') if args.nil?

      validate_path(parse[1], args[1])
    when 'rm', 'remove'
      validate_path(parse[1], parse[2])
    when 'sort'
      args = parse[2].match(%r{(.*)(\ )?(.*|text)?(\ )?(desc|asc)?$})
      raise(Puppet::Error, 'Invalid syntax for sort command') if args.nil?

      validate_path(parse[1], args[1])
    when 'match'
      query = parse[2].match(%r{(.*)\ size\ (==|!=|<|>|<=|>=)\ (\d)+$})
      raise(Puppet::Error, 'Invalid syntax for match conditional') if query.nil?

      validate_path(parse[1], query[1])
    when 'ins', 'insert'
      args = parse[2].match(%r{(.*)\ (before|after)\ (.*)$})
      raise(Puppet::Error, 'Invalid syntax for ins command') if args.nil?

      validate_path(parse[1], args[1])
    when 'get'
      query = parse[2].match(%r{^(.*)\ (==|!=|<|>|<=|>=)\ "(.*)"$})
      raise(Puppet::Error, 'Invalid syntax for get conditional') if query.nil?

      validate_path(parse[1], query[1])
    else
      raise(Puppet::Error, "Unrecognized command #{parse[1]}")
    end
  end

  def validate_path(prefix, value)
    raise(Puppet::Error, "#{prefix}: invalid xpath #{value}, path must be fully qualified") unless value =~ %r{^/}
  end
end
