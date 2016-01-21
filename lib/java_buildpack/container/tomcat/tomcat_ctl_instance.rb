# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/component/additional_libraries'
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for the Tomcat instance.
    class TomcatCtlInstance < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context) { |candidate_version| candidate_version.check_size(3) }
          
        @ctlenv = ENV['CTLENV'] || ".dev"
        # if I needed dynamic nil check http://stackoverflow.com/questions/7031804/most-elegant-way-to-check-nil-in-ruby
        #if(@ctlenv.empty?) 
        #  @ctlenv = ".dev"
        #end
        @ctlenvs = %w(.dev .int1 .int2 .int3 .itv1 .itv2 .itv3 .e2e .prod)          
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri) { |file| expand file }
          
        manipulate(@application.root.children)
        
        linkApps(@application.root)
        
        #add config files
        p = @application.root + "Qwest" + "config"
        @droplet.additional_classes   = AdditionalLibraries.new(@application.root) if @droplet.additional_classes.nil?
        p.children.each { | file | 
          puts "adding to CLASSPATH "
          puts file
          puts @droplet.additional_classes
          @droplet.additional_classes << file }
        ## common.loader="${catalina.base}/lib","${catalina.base}/lib/*.jar","${catalina.home}/lib","${catalina.home}/lib/*.jar"
        # alternative here is to add ${catalina.base}/../../Qwest/lib/*.jar and ${catalina.base}/../../Qwest/config 
        
        #add jar files
        ##p = @application.root + "Qwest" + "lib"
        ##p.children.each { | file | @droplet.additional_libraries << file if file.extname == ".jar" }
        
        # tibco 
        # http://lxomavmtc276.dev.qintra.com/pcf/tibco/tibco.zip
        
        # tibco 
        # http://lxomavmtc276.dev.qintra.com/pcf/tibco/tibco.zip
        
        @droplet.additional_libraries << tomcat_datasource_jar if tomcat_datasource_jar.exist?
        @droplet.additional_libraries.link_to web_inf_lib
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      protected

      def linkApps(root)
        apps = root + "Qwest" + "apps"
        link_to(apps.children, tomcat_webapps)
      end
      

      def manipulate(children)
        children.each { | file | 
          if(file.extname == @ctlenv) 
            # puts "rename "
            # http://stackoverflow.com/questions/15000615/changing-file-extension-using-ruby
            File.rename(file.to_s, "#{File.dirname(file.to_s)}/#{File.basename(file.to_s, '.*')}" )
          elsif (@ctlenvs.include? file.extname ) 
            # puts "delete "
            File.unlink file
          else 
            # puts "leave alone"
          end
          puts file 
          if(file.directory?) 
            manipulate(file.children)
          end
        }
      end
      
      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      TOMCAT_8 = JavaBuildpack::Util::TokenizedVersion.new('8.0.0').freeze

      private_constant :TOMCAT_8

      def configure_jasper
        return unless @version < TOMCAT_8

        document = read_xml server_xml
        server   = REXML::XPath.match(document, '/Server').first

        listener = REXML::Element.new('Listener')
        listener.add_attribute 'className', 'org.apache.catalina.core.JasperListener'

        server.insert_before '//Service', listener

        write_xml server_xml, document
      end

      def configure_linking
        document = read_xml context_xml
        context  = REXML::XPath.match(document, '/Context').first

        if @version < TOMCAT_8
          context.add_attribute 'allowLinking', true
        else
          context.add_element 'Resources', 'allowLinking' => true
        end

        write_xml context_xml, document
      end

      def expand(file)
        with_timing "Expanding #{@component_name} to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

          @droplet.copy_resources
          configure_linking
          configure_jasper
        end
      end

      def root
        context_path = (@configuration['context_path'] || 'ROOT').sub(%r{^/}, '').gsub(%r{/}, '#')
        tomcat_webapps + context_path
      end

      def tomcat_datasource_jar
        tomcat_lib + 'tomcat-jdbc.jar'
      end

      def web_inf_lib
        @droplet.root + 'WEB-INF/lib'
      end

    end

  end
end
