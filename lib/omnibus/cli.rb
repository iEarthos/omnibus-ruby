#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'thor'
require 'omnibus/version'
require 'mixlib/shellout'
require 'tempfile'

module Omnibus
  class CLI < Thor

    method_option :timestamp,
      :aliases => [:t],
      :type => :boolean,
      :default => true,
      :desc => "Append timestamp information to the version identifier?  Add a timestamp for nightly releases; leave it off for release and prerelease builds"

    method_option :path,
      :aliases => [:p],
      :type => :string,
      :default => Dir.pwd,
      :desc => "Path to Omnibus project root."

    desc "build project PROJECT", "Build the given Omnibus project"
    def build(dont_use_me, project)
      if looks_like_omnibus_project?(options[:path])
        say("Building #{project}", :green)

        say("*" * 50, :yellow)
        say("Andra Compatibility Mode", :yellow)
        say("*" * 50, :yellow)
        say("Checking omnibus.rb for compatibility...", :yellow)

        tmp = Tempfile.new("omnibus.rb")
        File.open("omnibus.rb", "r+") do |f|
          # check the first line for compatibility with old omnibus
          head = f.readline
          if head =~ /Omnibus\.configure/
            say("omnibus.rb is compatible, continuing...", :yellow)
          else
            say("omnibus.rb is incomatible, updating...", :yellow)
            say("Backing up omnibus.rb to omnibus.rb.backup...", :yellow)
            FileUtils.cp("omnibus.rb", "omnibus.rb.backup")

            tmp.puts("Omnibus.configure do |o|")
            f.rewind
            f.each_line do |line|
              # throw away empty lines
              next if line.strip.empty?

              # change method calls to attribute setters
              newline = line.split(/\s/, 2).join(" = ")
              tmp.puts("o.#{newline}")
            end
            tmp.puts("end")
          end
        end
        tmp.close()
        FileUtils.mv(tmp.path, "omnibus.rb")

        say("*" * 50, :yellow)

        unless options[:timestamp]
          say("I won't append a timestamp to the version identifier.", :yellow)
        end
        # Until we have time to integrate the CLI deeply into the Omnibus codebase
        # this will have to suffice! (sadpanda)
        env = {'OMNIBUS_APPEND_TIMESTAMP' => options[:timestamp].to_s}
        shellout!("rake projects:#{project} 2>&1", :environment => env, :cwd => options[:path])
      else
        raise Thor::Error, "Given path [#{options[:path]}] does not appear to be a valid Omnibus project root."
      end
    end

    desc "version", "Display version information"
    def version
      say("Omnibus: #{Omnibus::VERSION}", :yellow)
    end

    private

    def shellout!(command, options={})
      STDOUT.sync = true
      default_options = {
        :live_stream => STDOUT,
        :timeout => 7200, # 2 hours
        :environment => {}
      }
      shellout = Mixlib::ShellOut.new(command, default_options.merge(options))
      shellout.run_command
      shellout.error!
    end

    # Forces command to exit with a 1 on any failure...so raise away.
    def self.exit_on_failure?
      true
    end

    def looks_like_omnibus_project?(path)
      File.exist?(File.join(path, "Rakefile")) &&
        Dir["#{path}/config/projects/*.rb"].any?
    end
  end
end
