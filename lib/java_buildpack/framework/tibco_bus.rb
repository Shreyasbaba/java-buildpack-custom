# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling the Tibco JDBC client.
    # .\tibrvlisten.exe -service 7523 -network ";239.75.2.3" -daemon denvzd.qwest.net:7523 Q.RESED5.test.PCF
    class TibcoBus < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip false
        @droplet.copy_resources
        #@droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        #@droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        #true
        (@application.root + '**' + 'busconnector.xml').glob.any?
      end

      # Resolve the environment that's passed on the command line
      def resolve_command_environment
        # set MALLOC_ARENA_MAX by default
        @default_command_environment['LD_LIBRARY_PATH'] = './.java-buildpack/tibco_bus/lib/linux-i686:./.java-buildpack/tibco_bus/lib/linux-i686/ipm:./.java-buildpack/tibco_bus/lib/linux-x86_64:./.java-buildpack/tibco_bus/lib/linux-x86_64/64:./.java-buildpack/tibco_bus/lib/linux-x86_64/ipm' unless ENV.key? 'LD_LIBRARY_PATH'
      end

      private

      
    end

  end
end
