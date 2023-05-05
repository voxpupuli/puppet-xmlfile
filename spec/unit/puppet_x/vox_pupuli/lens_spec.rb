# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/vox_pupuli/xmlfile/lens'
require 'compare-xml'
require 'nokogiri'
require 'puppet/util/diff'

RSpec::Matchers.define :be_xml_equivalent_to do |expected_xml|
  match do |actual_xml|
    n1 = Nokogiri::XML(actual_xml)
    n2 = Nokogiri::XML(expected_xml)
    CompareXML.equivalent?(n1, n2, verbose: true).empty?
  end
end

# allows for interactive inspection when debugging
def xml_equivalent?(str1, _str2)
  n1 = Nokogiri::XML(str1)
  n2 = Nokogiri::XML(str1)
  raise ArgumentError if n1.nil? && n2.nil?

  CompareXML.equivalent?(n1, n2, verbose: true)
end

describe 'XmlLens' do
  let(:testobject) { XmlLens }

  # Build out tests as we come up with comparisons to augeas

  def lens_result(changes)
    PuppetX::VoxPupuli::Xmlfile::Lens.new(DOCUMENT, changes).evaluate.to_s
  end

  CONTENT = <<-'EOT'
  <beans
    xmlns="http://www.springframework.org/schema/beans"
    xmlns:amq="http://activemq.apache.org/schema/core"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
    http://activemq.apache.org/schema/core http://activemq.apache.org/schema/core/activemq-core.xsd">

      <bean class="org.springframework.beans.factory.config.PropertyPlaceholderConfigurer">
          <property name="locations">
              <value>file:${activemq.conf}/credentials.properties</value>
          </property>
      </bean>

      <broker xmlns="http://activemq.apache.org/schema/core" brokerName="localhost" dataDirectory="${activemq.data}">

          <destinationPolicy>
              <policyMap>
                <policyEntries>
                  <policyEntry topic=">" producerFlowControl="true">
                    <pendingMessageLimitStrategy>
                      <constantPendingMessageLimitStrategy limit="1000"/>
                    </pendingMessageLimitStrategy>
                  </policyEntry>
                  <policyEntry queue=">" producerFlowControl="true" memoryLimit="1mb">
                  </policyEntry>
                </policyEntries>
              </policyMap>
          </destinationPolicy>

          <managementContext>
              <managementContext createConnector="false"/>
          </managementContext>

          <persistenceAdapter>
              <kahaDB directory="${activemq.data}/kahadb"/>
          </persistenceAdapter>

            <systemUsage>
              <systemUsage>
                  <memoryUsage>
                      <memoryUsage limit="64 mb"/>
                  </memoryUsage>
                  <storeUsage>
                      <storeUsage limit="100 gb"/>
                  </storeUsage>
                  <tempUsage>
                      <tempUsage limit="50 gb"/>
                  </tempUsage>
              </systemUsage>
          </systemUsage>

          <transportConnectors>
              <transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
              <transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>
          </transportConnectors>

          <shutdownHooks>
              <bean xmlns="http://www.springframework.org/schema/beans" class="org.apache.activemq.hooks.SpringContextHook" />
          </shutdownHooks>

      </broker>

      <import resource="jetty.xml"/>

  </beans>
  EOT

  DOCUMENT = REXML::Document.new(CONTENT)

  describe 'set' do
    test_list = [
      {
        change: 'set /beans/broker/plugins/authorizationPlugin/map/authorizationMap/authorizationEntries/authorizationEntry/[last()+1]/#attribute/queue "test"',
        pattern: '</broker>',
        replacement: "<plugins><authorizationPlugin><map><authorizationMap><authorizationEntries><authorizationEntry queue='test'/></authorizationEntries></authorizationMap></map></authorizationPlugin></plugins></broker>"
      },
      {
        change: 'set /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/name == "amqp"]/#attribute/uri "udp://testuri"',
        pattern: '<transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>',
        replacement: '<transportConnector name="amqp" testattr="2" uri="udp://testuri"/>'
      }
    ]

    test_list.each do |test|
      if test[:pattern] != test[:replacement]
        it "#{test[:change]} should change XML" do
          result = lens_result(test[:change])
          expect(result).not_to be_xml_equivalent_to(CONTENT)
        end
      end

      it "#{test[:change]} should produce expected XML" do
        result = lens_result(test[:change])
        expected_result = CONTENT.gsub(test[:pattern], test[:replacement])
        diff = xml_equivalent?(result, expected_result)
        expect(diff.empty?).to be true
      end
    end
  end

  describe 'rm' do
    test_list = [
      {
        change: 'rm /beans/broker/plugins/authorizationPlugin/map/authorizationMap/authorizationEntries/authorizationEntry/[last()+1]/#attribute/queue "test"',
        pattern: '',
        replacement: ''
      },
      {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/name == "amqp"]',
        pattern: '<transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>',
        replacement: ''
      },
      {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/name == "amqp"][#attribute/testattr == "2"]',
        pattern: '<transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>',
        replacement: ''
      },
      {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/testattr == "2"][#attribute/name == "amqp"]',
        pattern: '<transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>',
        replacement: ''
      },
      {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/testattr == "2"][#attribute/name != "fake"]',
        pattern: '<transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600" testattr="2"/>',
        replacement: ''
      }
    ]

    it 'does not remove transport when testattr does not match' do
      test = {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/testattr != "2"][#attribute/name == "amqp"]',
        pattern: '',
        replacement: ''
      }
      result = lens_result(test[:change])
      expected_result = CONTENT.gsub(test[:pattern], test[:replacement])
      diff = xml_equivalent?(result, expected_result)
      expect(diff.empty?).to be true
    end

    it 'does not remove transport when name does not match' do
      test = {
        change: 'rm /beans/broker[#attribute/brokerName == "localhost"]/transportConnectors/transportConnector[#attribute/testattr == "2"][#attribute/name != "amqp"]',
        pattern: '',
        replacement: ''
      }
      result = lens_result(test[:change])
      expected_result = CONTENT.gsub(test[:pattern], test[:replacement])
      diff = xml_equivalent?(result, expected_result)
      expect(diff.empty?).to be true
    end

    test_list.each do |test|
      if test[:pattern] != test[:replacement]
        it "#{test[:change]} should change XML" do
          result = lens_result(test[:change])
          expect(result).not_to be_xml_equivalent_to(CONTENT)
        end
      end

      it "#{test[:change]} should produce expected XML" do
        result = lens_result(test[:change])
        expected_result = CONTENT.gsub(test[:pattern], test[:replacement])
        diff = xml_equivalent?(result, expected_result)
        expect(diff.empty?).to be true
      end
    end
  end
end
