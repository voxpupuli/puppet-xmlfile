# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:xmlfile) do
  let(:testobject) { Puppet::Type.type(:xmlfile) }

  # Test each of the inherited params and properties to ensure
  # validations are properly inherited.
  describe 'path' do
    it 'is fully-qualified' do
      expect do
        testobject.new(
          name: 'foo',
          path: 'my/path',
        )
      end.to raise_error(Puppet::Error, %r{paths must be fully qualified})
    end
  end

  describe 'ctime' do
    it 'is read-only' do
      expect do
        testobject.new(
          name: 'foo',
          path: '/my/path',
          ctime: 'somevalue',
        )
      end.to raise_error(Puppet::Error, %r{read-only})
    end
  end

  describe 'mtime' do
    it 'is read-only' do
      expect do
        testobject.new(
          name: 'foo',
          path: '/my/path',
          mtime: 'somevalue',
        )
      end.to raise_error(Puppet::Error, %r{read-only})
    end
  end

  describe 'group' do
    it 'does not accept empty values' do
      expect do
        testobject.new(
          name: 'foo',
          path: '/my/path',
          group: '',
        )
      end.to raise_error(Puppet::Error, %r{Invalid group name})
    end
  end

  describe 'mode' do
    it 'performs validations' do
      expect do
        testobject.new(
          name: 'foo',
          path: '/my/path',
          mode: 'fghl',
        )
      end.to raise_error(Puppet::Error, %r{file mode specification is invalid})
    end
  end

  describe 'source' do
    it 'does not accept a relative URL' do
      expect do
        testobject.new(
          name: 'foo',
          path: '/my/path',
          source: 'modules/puppet/file',
        )
      end.to raise_error(Puppet::Error, %r{Cannot use relative URLs})
    end
  end

  describe 'exist?' do
    it 'is true for an existing file' do
      Tempfile.create('xmlfile') do |f|
        expect(testobject.new(path: f.path).exist?).to be true
      end
    end

    it 'is false for a missing file' do
      expect(testobject.new(path: '/nonexistent/xmlfile.xml').exist?).to be false
    end
  end

  describe 'should_content' do
    it 'renders content with modifications' do
      catalog = Puppet::Resource::Catalog.new
      xmlfile = testobject.new(path: '/my/path', content: '<a/>')
      modification = Puppet::Type.type(:xmlfile_modification).new(
        name: 'set attr',
        file: '/my/path',
        changes: 'set /a/#attribute/b "c"',
      )
      catalog.add_resource(xmlfile, modification)

      expect(xmlfile.should_content).to eq("<a b='c'/>")
    end
  end
end
