require 'yaml'
require 'thor'
require 'hashdiff'
require 'diffy'

module Kaname
  class CLI < Thor
    desc 'password', 'Commands about updating user password'
    def password
      puts "current_user: #{Kaname::Config.username}"

      print "type your current password: "
      old_password = STDIN.noecho(&:gets).strip
      puts
      print "type your new password: "
      new_password = STDIN.noecho(&:gets).strip
      puts

      Kaname::Adapter::ReadAndWrite.new.update_user_password(old_password, new_password)
    end

    option :dryrun, type: :boolean
    desc 'apply', 'Commands about configuration apply'
    def apply
      adapter_klass = options[:dryrun] ? Kaname::Adapter::ReadOnly : Kaname::Adapter::ReadAndWrite
      adapter = adapter_klass.new(parallel: Kaname::Config.parallel)

      if Kaname::Resource.yaml
        diffs = HashDiff.diff(adapter.users_hash, Kaname::Resource.yaml)
        diffs.each do |diff|
          resource = diff[1].split('.')
          if resource.size == 1 # "user"
            if diff[0] == "+"
              user = adapter.create_user(resource[0], diff[2]['email'])
              diff[2]["tenants"].each do |tenant, role|
                adapter.create_user_role(tenant, user, role)
              end
            else
              adapter.delete_user(resource[0])
            end
          elsif resource.size == 3 # "user.tenants.foo"
            user_hash = adapter.find_user(resource[0])
            case diff[0]
            when "+"
              adapter.create_user_role(resource[2], user_hash, diff[2])
            when "-"
              adapter.delete_user_role(resource[2], user_hash, diff[2])
            when "~"
              adapter.change_user_role(resource[2], user_hash, diff[2], diff[3])
            end
          else # "user.tenants"
            # XXX
          end
        end
      else
        puts "Please put you keystone configuration file named keystone.yml to current directory."
      end
    end

    desc 'diff', 'Commands about show diffs from your openstack'
    def diff
      puts Diffy::Diff.new(YAML.dump(Kaname::Adapter::ReadOnly.new.users_hash), YAML.dump(Kaname::Resource.yaml))
    end

    desc 'dump', 'Commands about dump Keystone configuration.'
    def dump
      puts YAML.dump(Kaname::Adapter::ReadOnly.new.users_hash)
    end
  end
end
