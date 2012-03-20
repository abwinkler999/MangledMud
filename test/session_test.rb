require 'rubygems'
require 'test/unit'
require 'observer'
require 'bundler/setup'
require 'mocha'
require_relative 'include'
require_relative 'helpers'


module MangledMud

  # We need a fake here as mocha cannot handle emitting events
  class FakeGame
    include Observable

    def connect_player(user, password)
      1 # Hard wired to wizard
    end

    def process_command(player, command)
      changed
      notify_observers(player, command)
      false
    end
  end

  # To simplify assertions we disregard some phrasebook lookups, so this test would break
  # in obvious ways, if the phrasebook strings were modified
  class TestSession < Test::Unit::TestCase
    include TestHelpers

    def setup
      @db = MangledMud::Db.new()
    end

    def teardown
      @db.free()
    end

    def test_do_create
      @db = Db.Minimal()
      game = mock()
      game.expects(:add_observer).once()

      connected_players = mock()
      session = Session.new(@db, game, "foo", connected_players)
      assert(session.player_id.nil?, "player id should be nil")
      assert(session.last_time.nil?, "last command time should be nil")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0], "output buffer should be greeting player")
    end

    def test_do_command_quit
      @db = Db.Minimal()
      game = mock()
      game.expects(:add_observer).once()

      connected_players = mock()
      session = Session.new(@db, game, "foo", connected_players)

      assert(session.do_command(Phrasebook.lookup('quit-command')), "should return true if quit signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Disconnected/, session.output_buffer[0], "output buffer should be waving player goodbye")
    end

    def test_do_command_who
      @db = Db.Minimal()
      wizard = 1
      bob = Player.new(@db, nil).create_player("bob", "pwd")

      game = mock()
      game.expects(:add_observer).once()

      connected_players = mock()
      session = Session.new(@db, game, "foo", connected_players)

      session1 = mock()
      session2 = mock()
      session1.expects(:player_id).returns(wizard)
      session1.expects(:last_time).returns(nil)
      session2.expects(:player_id).returns(bob)
      session2.expects(:last_time).twice().returns(Time.parse("2012-03-09"))
      connected_players.expects(:call).returns([session1, session2])

      assert(!session.do_command(Phrasebook.lookup('who-command')), "should return false if quit isn't signalled")
      assert_equal(3, session.output_buffer.length)
      assert_match(/#{Phrasebook.lookup('current-players')}/, session.output_buffer[0], "start list players")
      assert_match(/Wizard idle forever/, session.output_buffer[1], "wizard had an inactive time")
      assert_match(/bob idle \d+ seconds/, session.output_buffer[2], "bob had an active time")
    end

    def test_do_command_prefix_and_suffix
      @db = Db.Minimal()
      wizard = 1
      game = mock()
      game.expects(:add_observer).once()
      connected_players = mock()

      session = Session.new(@db, game, "foo", connected_players)

      assert(!session.do_command(Phrasebook.lookup('prefix-command') + " prefix"), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/#{Phrasebook.lookup('done-fix')}/, session.output_buffer[0])

      assert(!session.do_command(Phrasebook.lookup('suffix-command') + " suffix"), "should return false if quit isn't signalled")
      assert_match(/#{Phrasebook.lookup('done-fix')}/, session.output_buffer[0])

      # Who should be wrapped
      connected_players.expects(:call).returns([])
      assert(!session.do_command(Phrasebook.lookup('who-command')), "should return false if quit isn't signalled")
      assert_equal(3, session.output_buffer.length)
      assert_match(/prefix/, session.output_buffer[0])
      assert_match(/#{Phrasebook.lookup('current-players')}/, session.output_buffer[1])
      assert_match(/suffix/, session.output_buffer[2])

      # So should quit
      assert(session.do_command(Phrasebook.lookup('quit-command')), "should return true if quit is signalled")
      assert_equal(3, session.output_buffer.length)
      assert_match(/prefix/, session.output_buffer[0])
      assert_match(/#{Regexp.escape(Phrasebook.lookup('leave-message').chomp())}/, session.output_buffer[1])
      assert_match(/suffix/, session.output_buffer[2])

      # So should a connected player - This requires a fake to test, see below
    end

    def test_connected_prefix_suffix
      # Due to game emitting events, we need to check that they end up in the queue, we can't
      # use mocha, or continue the above test, so more repeats (with fake)
      @db = Db.Minimal()
      wizard = 1
      game = FakeGame.new()
      connected_players = mock()

      session = Session.new(@db, game, "foo", connected_players)

      session.do_command(Phrasebook.lookup('prefix-command') + " prefix")
      session.do_command(Phrasebook.lookup('suffix-command') + " suffix")
      session.do_command('connect wizard potrzebie')
      session.do_command('cheese')

      assert_equal(3, session.output_buffer.length)
      assert_match(/prefix/, session.output_buffer[0])
      assert_match(/cheese/, session.output_buffer[1])
      assert_match(/suffix/, session.output_buffer[2])

      # Check that commands which return nothing result in an empty buffer
      session.do_command('')
      assert_equal(0, session.output_buffer.length)
    end

    def test_session_connect
      @db = Db.Minimal()
      wizard = 1
      game = mock()
      game.expects(:add_observer).times(5)
      connected_players = mock()
    
      session = Session.new(@db, game, "foo", connected_players)
    
      # connect should look
      game.expects(:connect_player).with('wizard', 'potrzebie').returns(wizard)
      game.expects(:process_command).with(wizard, 'look').returns(true)
      assert(!session.do_command('connect wizard potrzebie'), "should return false if quit isn't signalled")
      assert_equal(0, session.output_buffer.length)
    
      # When we are connected, unknown commands should route through to the game
      game.expects(:process_command).with(wizard, 'hello')
      assert(!session.do_command('hello'), "should return false if quit isn't signalled")

      # Known commands should route through game
      game.expects(:process_command).with(wizard, 'look')
      assert(!session.do_command('look'), "should return false if quit isn't signalled")

      # connect again, same user - Surely this should be a failure i.e. the player is already connected on another
      # descriptor? I guess its weird but safe?
      session = Session.new(@db, game, "foo", connected_players)
      game.expects(:connect_player).with('wizard', 'potrzebie').returns(wizard)
      game.expects(:process_command).with(wizard, 'look').returns(true)
      assert(!session.do_command('connect wizard potrzebie'), "should return false if quit isn't signalled")
      assert_equal(0, session.output_buffer.length)

      # connect failure
      session = Session.new(@db, game, "foo", connected_players)
      game.expects(:connect_player).with('foo', 'bar').returns(NOTHING)
      assert(!session.do_command('connect foo bar'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/#{Phrasebook.lookup('connect-fail').chomp}/, session.output_buffer[0])
      
      # Missing user and password
      session = Session.new(@db, game, "foo", connected_players)
      assert(!session.do_command('connect'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0])
      
      # Missing password
      session = Session.new(@db, game, "foo", connected_players)
      assert(!session.do_command('connect bar'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0])
    end
    
    def test_session_create
      @db = Db.Minimal()
      wizard = 1
      game = mock()
      game.expects(:add_observer).times(4)
      connected_players = mock()
    
      session = Session.new(@db, game, "foo", connected_players)
    
      # Create should look
      game.expects(:create_player).with('potato', 'head').returns(1) # ** map to wizard as we don't really create, stop explosions
      game.expects(:process_command).with(wizard, 'look').returns(true)
      assert(!session.do_command('create potato head'), "should return false if quit isn't signalled")
      assert_equal(0, session.output_buffer.length)

      # When we are connected, unknown commands should route through to the game
      game.expects(:process_command).with(wizard, 'hello')
      assert(!session.do_command('hello'), "should return false if quit isn't signalled")
    
      # Check create failure
      session = Session.new(@db, game, "foo", connected_players)
      game.expects(:create_player).with('potato', 'head').returns(NOTHING)
      assert(!session.do_command('create potato head'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/#{Phrasebook.lookup('create-fail').chomp}/, session.output_buffer[0])
    
      # Missing user and password - Never hits creation
      session = Session.new(@db, game, "foo", connected_players)
      assert(!session.do_command('create'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0])
    
      # Missing password - Never hits creation
      session = Session.new(@db, game, "foo", connected_players)
      assert(!session.do_command('create bar'), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0])
    end

    def test_unconnected_unrecognized_command
      @db = Db.Minimal()
      wizard = 1
      game = mock()
      game.expects(:add_observer).once()
      connected_players = mock()
    
      session = Session.new(@db, game, "foo", connected_players)
    
      assert_raise RuntimeError do
        assert(!session.do_command(nil), "should return false if quit isn't signalled")
      end
    
      assert(!session.do_command("cheese string"), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/Welcome to MangledMUD/, session.output_buffer[0])
    end

    def test_shutdown
      @db = Db.Minimal()
      wizard = 1
      game = mock()
      game.expects(:add_observer).once()
      game.expects(:delete_observer).once()
      connected_players = mock()
    
      session = Session.new(@db, game, "foo", connected_players)
      assert(!session.do_command(Phrasebook.lookup('prefix-command') + " prefix"), "should return false if quit isn't signalled")
      assert_equal(1, session.output_buffer.length)
      assert_match(/#{Phrasebook.lookup('done-fix')}/, session.output_buffer[0])

      assert(!session.do_command(Phrasebook.lookup('suffix-command') + " suffix"), "should return false if quit isn't signalled")
      assert_match(/#{Phrasebook.lookup('done-fix')}/, session.output_buffer[0])

      session.shutdown()
      assert_equal(3, session.output_buffer.length)
      assert_match(/prefix/, session.output_buffer[0])
      assert_match(/#{Regexp.escape(Phrasebook.lookup('shutdown-message').chomp())}/, session.output_buffer[1])
      assert_match(/suffix/, session.output_buffer[2])
    end
  end
end
