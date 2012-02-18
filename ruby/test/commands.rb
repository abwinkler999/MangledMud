# Helpers for running "commands" regressions, used by run_command.rb
# and regression.rb
require 'rubygems'
require 'test/unit'
require 'bundler/setup'
require 'mocha'
require_relative 'include'

module TinyMud
    
    # Consider mixing this in?
    class CommandHelpers

        # This is naff :-)
        def CommandHelpers.AliasInterface
            class << Interface
                alias_method :old_do_notify, :do_notify

                def Interface.set_out(out)
                    @out = out
                end
        
                def do_notify(player, message)
                    @out << "\t\e[31;1m#{player} #{message}\e[0m\n"
                end
            end
            Interface.expects(:do_emergency_shutdown).never
        end
        
        # This is naff :-)
        def CommandHelpers.DeAliasInterface
            class << Interface
                alias_method :get, :old_do_notify
            end
        end

        # Given db, find thing by name
        def CommandHelpers.find(db, name)
            for i in 0..(db.length - 1)
                return i if db[i].name == name
            end
            raise "Find #{name} failed!"
        end
        
        # Read content, apply commands to db (note the db is currently static
        # this will change at some point - As I migrate the C code over)
        def CommandHelpers.collect_responses(db, content)

            players = { "wizard" => 1 }
            game = TinyMud::Game.new(db)

            # Ensure we never give pennies and never manage to kill
			Game.stubs(:do_rand).returns(17)

            result = []
            
            Interface.set_out(result)
            
            content.each do |line|
                if line !~ /^\s*#/ # Skip comments
                    if line =~ /^\s*!(.*)/ # Is a special command line?
                        cmds = $1.split(' ')
                        if cmds[0] == "create_player"
                            result << "Creating player: \"#{cmds[1]}\" with password \"#{cmds[2]}\"\n"
                            players[cmds[1]] = TinyMud::Player.new(db).create_player(cmds[1], cmds[2])
                        elsif cmds[0] == "dumpfile"
                            result << "Setting dump file name to #{cmds[1]}\n"
                            Game::set_dumpfile_name(cmds[1])
                        elsif cmds[0] == "@dump"
                            result << "Dumping database\n"
                            Game::dump_database_to_file('cheese.dump')
                        elsif cmds[0] == "load"
                            result << "Reading database from: " << cmds[1] << "\n"
                            db.read(cmds[1])
                        end
                    elsif line =~ /^(\w+)>(.*)/
                        player = $1
                        command = $2.strip
                        raise "Unkown player: \"#{player}\"" unless players.has_key?(player)
                        result << "\e[32;1m#{player}(#{players[player]}): #{command}\e[0m\n"
                        # Replace #{name} with identifier - This makes the text tests more robust
                        # Can only handle one per line at present (all I need for now)
                        if command =~ /\{(.*?)\}/
                            what = $1
                            command.gsub!(/\{(.*?)\}/, "#{CommandHelpers.find(db, what)}")
                        end
                        game.process_command(players[player], command)
                    elsif line.strip.length != 0
                        result << "Failed parsing line: #{line}\n"
                    end
                end
            end
            
            result
        end
        
    end
end
