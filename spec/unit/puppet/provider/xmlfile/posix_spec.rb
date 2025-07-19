# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:xmlfile).provide(:xmlfile_posix) do
  let(:testobject) { Puppet::Type.type(:xmlfile).provide(:xmlfile_posix) }

  it 'correct class' do
    puts testobject.class
    expect(testobject).to be_a Object
  end
end
