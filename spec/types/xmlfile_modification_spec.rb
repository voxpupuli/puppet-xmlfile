require 'spec_helper'

describe Puppet::Type.type(:xmlfile_modification) do
  let(:testobject) { Puppet::Type.type(:xmlfile_modification) }

  describe 'file' do
    it 'is a fully-qualified path' do
      expect do
        testobject.new(
          name: 'foo',
          file: 'my/path'
        )
      end.to raise_error(Puppet::Error, %r{paths must be fully qualified})
    end
  end

  describe 'changes' do
    it 'requires a fully-qualified xpath' do
      expect do
        testobject.new(
          name: 'test',
          file: '/my/path',
          changes: ['set blah/bloo/hah "test"']
        )
      end.to raise_error(Puppet::Error, %r{invalid xpath})
    end
    it 'does not accept invalid commands' do
      expect do
        testobject.new(
          name: 'test',
          file: '/my/path',
          changes: ['sets /blah/bloo/hah "test"']
        )
      end.to raise_error(Puppet::Error, %r{Unrecognized command})
    end
    describe 'ins' do
      it 'validates syntax' do
        expect do
          testobject.new(
            name: 'test',
            file: '/my/path',
            changes: ['ins blue befores red']
          )
        end.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
    describe 'set' do
      it 'validates syntax' do
        expect do
          testobject.new(
            name: 'test',
            file: '/my/path',
            changes: ['set /blah/bloo/hah test']
          )
        end.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
  end

  describe 'onlyif' do
    it 'requires a fully-qualified xpath' do
      expect do
        testobject.new(
          name: 'test',
          file: '/my/path',
          onlyif: ['get blah/bloo/hah == "test"']
        )
      end.to raise_error(Puppet::Error, %r{invalid xpath})
    end
    it 'does not accept invalid commands' do
      expect do
        testobject.new(
          name: 'test',
          file: '/my/path',
          onlyif: ['gets /blah/bloo/hah "test"']
        )
      end.to raise_error(Puppet::Error, %r{Unrecognized command})
    end
    describe 'get' do
      it 'validates syntax' do
        expect do
          testobject.new(
            name: 'test',
            file: '/my/path',
            onlyif: ['get /blah/bloo/hah test']
          )
        end.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end

    describe 'match' do
      it 'validates syntax' do
        expect do
          testobject.new(
            name: 'test',
            file: '/my/path',
            onlyif: ['match /blah/bloo/hah test']
          )
        end.to raise_error(Puppet::Error, %r{Invalid syntax})
      end
    end
  end
end
