require 'spec_helper'

describe Puppet::Type.type(:xmlfile).provide(:xmlfile_windows) do
  let(:testobject) { Puppet::Type.type(:xmlfile).provide(:xmlfile_windows) }

  it 'correct class' do
    expect(testobject).to be_a Object
  end
end
