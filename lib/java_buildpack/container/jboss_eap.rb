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

require 'java_buildpack/component/modular_component'
require 'java_buildpack/container'
require 'java_buildpack/container/jboss/eap_ctl_instance'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat applications.
    class JbossEap < JavaBuildpack::Component::ModularComponent

      protected

      # (see JavaBuildpack::Component::ModularComponent#command)
      def command
        @droplet.java_opts.add_system_property 'http.port', '$PORT'
        update_configuration
        
        [
          @droplet.java_home.as_env_var,
          @droplet.java_opts.as_env_var,
          "$PWD/#{(@droplet.sandbox + 'bin/standalone.sh').relative_path_from(@droplet.root)}",
          "-b=0.0.0.0"
        ].flatten.compact.join(' ')
      end

      # (see JavaBuildpack::Component::ModularComponent#sub_components)
      def sub_components(context)
        [
          EapCtlInstance.new(sub_configuration_context(context, 'jboss')),
          #TomcatLifecycleSupport.new(sub_configuration_context(context, 'lifecycle_support')),
          #TomcatLoggingSupport.new(sub_configuration_context(context, 'logging_support')),
          #TomcatAccessLoggingSupport.new(sub_configuration_context(context, 'access_logging_support')),
          #TomcatRedisStore.new(sub_configuration_context(context, 'redis_store')),
          #TomcatGemfireStore.new(sub_configuration_context(context, 'gemfire_store')),
          #TomcatInsightSupport.new(context)
        ]
      end

      # (see JavaBuildpack::Component::ModularComponent#supports?)
      def supports?
        eap_zip? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)
      end

      private

      def ews_tar?
        (@application.root + 'deployments').exist?
      end

    end

    def update_configuration
      standalone_config = @droplet.sandbox + 'standalone/configuration/standalone.xml'

      modified = standalone_config.read.
        gsub(/<socket-binding name="http" port="8080"\/>/,
            '<socket-binding name="http" port="${http.port}"/>')
#                   .gsub(/<virtual-server name="default-host" enable-welcome-root="true">/,
#                         '<virtual-server name="default-host" enable-welcome-root="false">')

      standalone_config.open('w') { |f| f.write modified }
    end

  end
end
