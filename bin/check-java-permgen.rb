#! /usr/bin/env ruby
#
#  java-permgen
#
# DESCRIPTION:
#   Java PermGen Check
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'English'

#
# Check Java
#
class CheckJavaPermGen < Sensu::Plugin::Check::CLI
  check_name 'Java PermGen'

  option :warn, short: '-w WARNLEVEL', default: '85'
  option :crit, short: '-c CRITLEVEL', default: '95'
  option :as_sudo, short: '-s', description: 'Run as sudo', boolean: true, required: false
  option :java, short: '-j <java bin dir>', description: 'java bin dir, including trailing slash', default: ''

  def run
    warn_procs = []
    crit_procs = []
    java_pids = []
    sudo = config[:as_sudo] ? 'sudo ' : ''

    IO.popen("#{sudo}#{config[:java]}jps -q") do |cmd|
      java_pids = cmd.read.split
    end

    java_pids.each do |java_proc|
      pgcmx = nil
      pu = nil
      IO.popen("#{sudo}#{config[:java]}jstat -gcpermcapacity #{java_proc} 1 1 2>&1") do |cmd|
        pgcmx = cmd.read.split[9]
      end
      exit_code = $CHILD_STATUS.exitstatus
      next if exit_code != 0

      IO.popen("#{sudo}#{config[:java]}jstat -gcold #{java_proc} 1 1 2>&1") do |cmd|
        pu = cmd.read.split[9]
      end
      exit_code = $CHILD_STATUS.exitstatus
      next if exit_code != 0

      proc_permgen = (pu / pgcmx.to_f) * 100
      warn_procs << java_proc if proc_permgen > config[:warn].to_f
      crit_procs << java_proc if proc_permgen > config[:crit].to_f
    end

    if !crit_procs.empty?
      critical "Java processes Over PermGen CRIT threshold of #{config[:crit]}%: #{crit_procs.join(', ')}"
    elsif !warn_procs.empty?
      warning "Java processes Over PermGen WARN threshold of #{config[:warn]}%: #{warn_procs.join(', ')}"
    else
      ok 'No Java processes over PermGen thresholds'
    end
  end
end
