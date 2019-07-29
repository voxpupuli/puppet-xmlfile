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
          path: 'my/path'
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
          ctime: 'somevalue'
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
          mtime: 'somevalue'
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
          group: ''
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
          mode: 'fghl'
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
          source: 'modules/puppet/file'
        )
      end.to raise_error(Puppet::Error, %r{Cannot use relative URLs})
    end
  end
end
