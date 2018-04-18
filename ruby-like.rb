#!/usr/bin/env ruby

require "ncurses"
require "matrix"

BEGIN{
  # Resizing terminal window 50 x 100 
  print "\e[8;50;100t"
}

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

  def erase_windows
    @game.clear
    @hud.clear
    @game.border(*([0]*8))
    @hud.border(*([0]*8))
  end

  def hud_message(str)
    @hud.mvaddstr(0, 1, str)
  end

  def display_inventory()
    (1..9).each do |i|
      if i == PLAYER.active_inventory
        @hud.attron(Ncurses.COLOR_PAIR(2))
        @hud.mvaddstr(1, (i * 6) - 5, i.to_s)
        @hud.mvaddstr(2, (i * 6) - 5, "v")
        @hud.attroff(Ncurses.COLOR_PAIR(2))
      else
        @hud.mvaddstr(1, (i * 6) - 5, i.to_s)
        @hud.mvaddstr(2, (i * 6) - 5, "v")
      end
    end
    i = 1
    PLAYER.inventory.each do |type, quantity|
      @hud.attron(Ncurses.COLOR_PAIR(type))
      @hud.mvaddstr(3, i, TILES[type])
      @hud.attroff(Ncurses.COLOR_PAIR(type))
      @hud.mvaddstr(3, i + 1, ": " + quantity.to_s)
      i *= 7
    end
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
        @game.attron(Ncurses.COLOR_PAIR(1))
        @game.mvaddstr(position[1],position[0], "░".to_s)
        #@game.mvaddch(position[1],position[0], 35)
        @game.attroff(Ncurses.COLOR_PAIR(1))
      when 2
        @game.attron(Ncurses.COLOR_PAIR(2))
        @game.mvaddstr(position[1],position[0], "░".to_s)
        #@game.mvaddch(position[1],position[0], 97 | Ncurses::A_ALTCHARSET)
        @game.attroff(Ncurses.COLOR_PAIR(2))
      else
        @game.mvaddch(position[1],position[0], 32)
      end
    end
  end

  def draw_entities(entities)
    for i in 0...entities.length
      @game.attron(Ncurses.COLOR_PAIR(4))
      @game.mvaddstr(entities[i].position[1], entities[i].position[0], entities[i].char)
      @game.attroff(Ncurses.COLOR_PAIR(4))
      if entities[i].crosshairs
        @game.attron(Ncurses.COLOR_PAIR(3))
        @game.mvaddstr(entities[i].crosshairs[1], entities[i].crosshairs[0], "+".to_s)
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
    return true if (MAP[@position + Vector[1,1]].type !=0 || MAP[@position + Vector[-1,1]].type !=0) #Ledge
    return false # Mid-air or nil
  end

end

class Chunk
  attr_reader :position, :tiles
  def initialize(position)
    @position = position
    @tiles = {}
    create_tiles()
  end

  def create_tiles
    for y in CHUNK_HEIGHT
      for x in CHUNK_WIDTH
        @tiles[@position + Vector[x,y]] = Tile.new(@position + Vector[x,y])
      end
    end
  end

end

class Map
  attr_accessor :chunks
  def initialize
    @chunks = {}
    load_chunks()
  end
  def load_chunks
    if @chunks.length == 0
    end
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
    return false if !MAP[@postion].is_navigable
    return true
  end

end

class Player < Entity
  attr_accessor :crosshairs, :inventory, :active_inventory
  def initialize(position)
    super(position)
    @char = "☺".to_s
    while MAP[@position + Vector[0,1]].type == 0
      @position += Vector[0,1]
    end
    @crosshairs = @position + Vector[1,0]
    @inventory = Hash.new
    @active_inventory = 1
  end

  def add_to_inventory(type)
    if @inventory[type] != nil
      @inventory[type] += 1
    else
      @inventory[type] = 1
    end
  end

  def remove_from_inventory(type)
    if @inventory[type] == nil
      return
    end
    if @inventory[type] > 0
      @inventory[type] -= 1
    end
    if @inventory[type] == 0
      @inventory.delete(type)
    end
  end

end


def handle_input(input)
  case 
  when input == KEYS['w']
    if (PLAYER.crosshairs == PLAYER.position - Vector[0,1]) && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position -= Vector[0,1]
      PLAYER.crosshairs -= Vector[0,1]
    else
      PLAYER.crosshairs = PLAYER.position - Vector[0,1] 
    end

  when input == KEYS['s']
    if PLAYER.crosshairs == PLAYER.position + Vector[0,1] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position += Vector[0,1]
      PLAYER.crosshairs += Vector[0,1]
    else
      PLAYER.crosshairs = PLAYER.position + Vector[0,1]
    end

  when input == KEYS['a']
    if PLAYER.crosshairs == PLAYER.position - Vector[1,0] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position -= Vector[1,0]
      PLAYER.crosshairs -= Vector[1,0]
    else
      PLAYER.crosshairs = PLAYER.position - Vector[1,0]
    end

  when input == KEYS['d']
    if PLAYER.crosshairs == PLAYER.position + Vector[1,0] && MAP[PLAYER.crosshairs].is_navigable
      PLAYER.position += Vector[1,0]
      PLAYER.crosshairs += Vector[1,0]
    else
      PLAYER.crosshairs = PLAYER.position + Vector[1,0]
    end
  
  when input == KEYS['e']
    if MAP[PLAYER.crosshairs].type != 0
      PLAYER.add_to_inventory(MAP[PLAYER.crosshairs].type)
      MAP[PLAYER.crosshairs].type = 0
    end

  when input == KEYS['q']
    if PLAYER.inventory[PLAYER.active_inventory] == nil
      return
    end
    if MAP[PLAYER.crosshairs].type == 0
      PLAYER.remove_from_inventory(PLAYER.active_inventory)
      MAP[PLAYER.crosshairs].type = PLAYER.active_inventory
    end
  when input.between?(49,57)
    # Manages inventory slots
    # ASCII codes for 1-9 are 49-57
    PLAYER.active_inventory = input - 48
  end

end

begin
  

  # initialize ncurses
  Ncurses.initscr
  #Ncurses.resizeterm(100,100)
  Ncurses.cbreak           # provide unbuffered input
  Ncurses.noecho           # turn off input echoing
  Ncurses.nonl             # turn off newline translation
  Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
  Ncurses.stdscr.keypad(true)     # turn on keypad mode

  Ncurses.start_color
  Ncurses.init_pair(1, Ncurses::COLOR_GREEN, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(2, Ncurses::COLOR_BLACK, Ncurses::COLOR_WHITE)
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
    'q' => 113,
    'POUND' => 35,
    'SPACE' => 32,
    'AT' => 64,
    'ESC' => 27,
    'y' => 121,
    'PLUS' => 43,
    '1' => 49,
    '2' => 50,
    '3' => 51,
    '4' => 52,
    '5' => 53,
    '6' => 54,
    '7' => 55,
    '8' => 56,
    '9' => 57
  ]
  TILES = [
    " ".to_s, # 0
    "░".to_s, # 1
    "░".to_s, # 2
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
    window_manager.erase_windows()
    handle_input(input)
    window_manager.draw_terrain(terrain.terrain_hash)
    
    window_manager.draw_entities(ENTITIES)
    window_manager.hud_message("Press esc to quit")
    window_manager.hud_message("Player: ("+PLAYER.position[0].to_s+
    ", "+PLAYER.position[1].to_s+")")
    window_manager.display_inventory
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


