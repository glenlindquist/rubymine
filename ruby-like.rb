
#!/usr/bin/env ruby

require "ncurses"
require "matrix"

class WindowManager
  attr_accessor :game, :hud
  attr_reader :game_height, :game_width
  def initialize()
    @game = Ncurses::WINDOW.new(GAME_HEIGHT + 2, 0, 0, 0)
    @hud = Ncurses::WINDOW.new(Ncurses.LINES() - GAME_HEIGHT - 2, 0, GAME_HEIGHT + 2, 0)
    @game.border(*([0]*8))
    @hud.border(*([0]*8))

  end

  def to_virtual_screen
    @game.noutrefresh()
    @hud.noutrefresh()
  end

  def hud_message(str)
    @hud.mvaddstr(0,1,str)
  end

  def draw_game(terrain_hash, entities)
    draw_terrain(terrain_hash)
    draw_entities(entities)
  end

  def draw_terrain(terrain_hash)
    terrain_hash.each do |position, tile|
      case tile.type
      when 0
        @game.mvaddch(position[1],position[0], 32)
      when 1
        @game.attron(Ncurses.COLOR_PAIR(2))
        @game.mvaddstr(position[1],position[0], "░".to_s)
        #@game.mvaddch(position[1],position[0], 35)
        @game.attroff(Ncurses.COLOR_PAIR(2))
      when 2
        @game.attron(Ncurses.COLOR_PAIR(1))
        @game.mvaddstr(position[1],position[0], "░".to_s)
        #@game.mvaddch(position[1],position[0], 97 | Ncurses::A_ALTCHARSET)
        @game.attroff(Ncurses.COLOR_PAIR(1))
      else
        @game.mvaddch(position[1],position[0], 32)
      end
    end
  end

  def draw_entities(entities)
    for i in 0...entities.length
      @game.attron(Ncurses.COLOR_PAIR(4))
      @game.mvaddch(entities[i].position[1], entities[i].position[0], entities[i].char)
      @game.attroff(Ncurses.COLOR_PAIR(4))
      if entities[i].crosshairs
        @game.attron(Ncurses.COLOR_PAIR(3))
        @game.mvaddch(entities[i].crosshairs[1], entities[i].crosshairs[0], KEYS['PLUS'])
        @game.attroff(Ncurses.COLOR_PAIR(3))
      end
    end
  end

end

class Position
  attr_reader :x, :y
  def initialize(x,y)
    @vector_position = Vector[x,y]
    @x = @vector_position[0]
    @y = @vector_position[1]
  end
end
 
class Terrain
  attr_accessor :terrain_hash
  def initialize()
    @terrain_hash = Hash.new
    for y in 1...(GAME_HEIGHT + 1)
      for x in 1...(GAME_WIDTH + 1)
        @terrain_hash[Vector[x,y]] = Tile.new(Vector[x,y])
      end
    end
  end

  def create_ground()
    for y in (GAME_HEIGHT / 2).floor...(GAME_HEIGHT + 1)
      for x in 1...(GAME_WIDTH + 1)
        if y == (GAME_HEIGHT / 2).floor
          @terrain_hash[Vector[x,y]].type = 1
        else
          @terrain_hash[Vector[x,y]].type = 2
        end
      end
    end
  end

end

class Tile
  attr_reader :position
  attr_accessor :type
  def initialize(position)
    @position = position
    @type = 0 # Defaults to empty
  end

  def is_navigable
    return false if type != 0 # Solid
    return true if MAP[@position + Vector[0,1]].type != 0 # On Ground
    return true if (MAP[@position + Vector[1,0]].type !=0 || MAP[@position - Vector[1,0]].type !=0) # Wall-adjacent
    return true if (MAP[@position + Vector[1,1]].type !=0 || MAP[@position + Vector[-1,1]].type !=0) #Leddge
    return false # Mid-air
  end


end

class EntitiesManager
  attr_accessor :entities
  def initialize
    @entities = []
  end

  def update
    # Runs once per frame
    self.ground_entities
  end

  def ground_entities
    # Checks to see if anyone is off the ground and grounds them
    for i in 0...@entities.length
      while !@entities[i].is_grounded
        @entities[i].position += Vector[0,1]
      end
    end
  end
  
end

class Entity
  attr_accessor :position, :char
  def initialize(position, char = 33)
    ENTITIES << self
    @position = position
  end

  def is_grounded
    return false if MAP[@postion + Vector[0,1]].type == 0
    return true
  end

end

class Player < Entity
  attr_accessor :crosshairs, :inventory
  def initialize(position)
    super(position)
    @char = 64
    while MAP[@position + Vector[0,1]].type == 0
      @position += Vector[0,1]
    end
    @crosshairs = @position + Vector[1,0]
    @inventory = []
  end
end

def handle_input(input)
  case input
  when KEYS['w']
    if (PLAYER.crosshairs == PLAYER.position - Vector[0,1]) && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position -= Vector[0,1]
      PLAYER.crosshairs -= Vector[0,1]
    else
      PLAYER.crosshairs = PLAYER.position - Vector[0,1] 
    end

  when KEYS['s']
    if PLAYER.crosshairs == PLAYER.position + Vector[0,1] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position += Vector[0,1]
      PLAYER.crosshairs += Vector[0,1]
    else
      PLAYER.crosshairs = PLAYER.position + Vector[0,1]
    end

  when KEYS['a']
    if PLAYER.crosshairs == PLAYER.position - Vector[1,0] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position -= Vector[1,0]
      PLAYER.crosshairs -= Vector[1,0]
    else
      PLAYER.crosshairs = PLAYER.position - Vector[1,0]
    end

  when KEYS['d']
    if PLAYER.crosshairs == PLAYER.position + Vector[1,0] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position += Vector[1,0]
      PLAYER.crosshairs += Vector[1,0]
    else
      PLAYER.crosshairs = PLAYER.position + Vector[1,0]
    end
  
  when KEYS['e']
    if MAP[PLAYER.crosshairs].type != 0
      PLAYER.inventory << MAP[PLAYER.crosshairs].type
      MAP[PLAYER.crosshairs].type = 0
    end
  end
end

begin
  # initialize ncurses
  Ncurses.initscr
  Ncurses.cbreak           # provide unbuffered input
  Ncurses.noecho           # turn off input echoing
  Ncurses.nonl             # turn off newline translation
  Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
  Ncurses.stdscr.keypad(true)     # turn on keypad mode

  Ncurses.start_color
  Ncurses.init_pair(1, Ncurses::COLOR_BLACK, Ncurses::COLOR_WHITE)
  Ncurses.init_pair(2, Ncurses::COLOR_GREEN, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(3, Ncurses::COLOR_RED, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(4, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK)

  GAME_HEIGHT = (Ncurses.LINES() * 0.8).floor - 2
  GAME_WIDTH = Ncurses.COLS() - 2
  ENTITIES = []
  KEYS = Hash[
    'w' => 119,
    'a' => 97,
    's' => 115,
    'd' => 100,
    'e' => 101,
    'POUND' => 35,
    'SPACE' => 32,
    'AT' => 64,
    'ESC' => 27,
    'y' => 121,
    'PLUS' => 43
  ]

  window_manager = WindowManager.new()
  terrain = Terrain.new()
  terrain.create_ground
  MAP = terrain.terrain_hash
  PLAYER = Player.new(Vector[1,1])
  window_manager.draw_terrain(terrain.terrain_hash)
  window_manager.draw_entities(ENTITIES)
  window_manager.hud_message("Press esc to quit")
  window_manager.to_virtual_screen
  Ncurses.doupdate()

  # main game loop
  input = 0
  Ncurses.curs_set(0)
  while(input != KEYS['ESC'])
    handle_input(input)
    window_manager.draw_terrain(terrain.terrain_hash)
    
    window_manager.draw_entities(ENTITIES)
    window_manager.hud_message("Press esc to quit")
    window_manager.hud_message("Player: ("+PLAYER.position[0].to_s+
    ", "+PLAYER.position[1].to_s+")")
    window_manager.to_virtual_screen
    Ncurses.doupdate()
    input = Ncurses.wgetch(window_manager.game)
    
  end

ensure
  Ncurses.echo
  Ncurses.nocbreak
  Ncurses.nl
  Ncurses.endwin
end


