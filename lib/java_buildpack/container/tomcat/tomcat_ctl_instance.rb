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
        
        link_to(getApp(@application.root).children, root)
        linkApps(@application.root)
        
        #add config files
        p = @application.root + "Qwest" + "config"
        p.children.each { | file | @droplet.additional_classes << file }
        @droplet.additional_classes.link_to web_inf_classes
        ## common.loader="${catalina.base}/lib","${catalina.base}/lib/*.jar","${catalina.home}/lib","${catalina.home}/lib/*.jar"
        # alternative here is to add ${catalina.base}/../../Qwest/lib/*.jar and ${catalina.base}/../../Qwest/config 
        
        #add jar files
        ##p = @application.root + "Qwest" + "lib"
        ##p.children.each { | file | @droplet.additional_libraries << file if file.extname == ".jar" }
        
        # tibco 
        # http://lxomavmtc276.dev.qintra.com/pcf/tibco/tibco.zip
        
        @droplet.additional_libraries << tomcat_datasource_jar if tomcat_datasource_jar.exist?
        @droplet.additional_libraries.link_to web_inf_lib
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      protected

      # find web app
      def getApp(root)
        # apps are in ./Qwest/apps
        apps = root + "Qwest" + "apps"
        # pick the first one - we can get fancy later
        # please note, the same app will also be linked in under it's name via symbolic link
        # i.e. deployed twice
        apps.children[0]
      end
      
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
        with_timing "Expanding EAP to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p @droplet.sandbox
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

          @droplet.copy_resources
          configure_linking
          configure_jasper
        end
      end

      def root
        tomcat_webapps + 'ROOT'
      end

      def tomcat_datasource_jar
        tomcat_lib + 'tomcat-jdbc.jar'
      end

      def web_inf_lib
        getApp(@droplet.root) + 'WEB-INF/lib'
      end
      
      def web_inf_classes
        getApp(@droplet.root) + 'WEB-INF/classes'
      end

    end

  end
end
