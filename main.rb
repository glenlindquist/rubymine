#!/usr/bin/env ruby

require "ncurses"
#gem ncurses-ruby
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
    #@game.clear
    @hud.clear
    @game.border(*([0]*8))
    @hud.border(*([0]*8))
  end

  def hud_message(str)
    @hud.mvaddstr(0, 1, str)
  end

  def display_inventory()
    (1..9).each do |i|
      if i == PLAYER.hotbar_active
        @hud.attron(Ncurses.COLOR_PAIR(2))
        @hud.mvaddstr(1, (i * 6) - 5, i.to_s)
        @hud.mvaddstr(2, (i * 6) - 5, "v")
        @hud.attroff(Ncurses.COLOR_PAIR(2))
      else
        @hud.mvaddstr(1, (i * 6) - 5, i.to_s)
        @hud.mvaddstr(2, (i * 6) - 5, "v")
      end
    end
    PLAYER.hotbar.each do |slot, item|
      if PLAYER.hotbar[slot] != nil
        @hud.attron(Ncurses.COLOR_PAIR(PLAYER.hotbar[slot]))
        @hud.mvaddstr(3, (slot * 6) - 5, TILES[PLAYER.hotbar[slot]])
        @hud.attroff(Ncurses.COLOR_PAIR(PLAYER.hotbar[slot]))
        @hud.mvaddstr(3, (slot * 6) - 4, ": " + PLAYER.inventory[item].to_s)
      end
    end
  end

  def draw_game()
    draw_terrain()
    draw_entities()
  end

  def draw_terrain()
    for y in 1...(GAME_HEIGHT + 1)
      for x in 1...(GAME_WIDTH + 1)
        draw_tile(x, y)
      end
    end
  end

  def draw_tile(x, y)
    if MAP[Vector[x,y] + CAMERA.position] == nil
      @game.attron(Ncurses.COLOR_PAIR(99))
      @game.mvaddstr(y, x, TILES[0])
      @game.attroff(Ncurses.COLOR_PAIR(99))
    else
      tile_type = MAP[Vector[x,y] + CAMERA.position].type
      @game.attron(Ncurses.COLOR_PAIR(tile_type))
      @game.mvaddstr(y, x, TILES[tile_type])
      @game.attroff(Ncurses.COLOR_PAIR(tile_type))
    end
  end

  def draw_entities(entities)
    for i in 0...entities.length
      position_x = entities[i].position[0] - CAMERA.position[0]
      position_y = entities[i].position[1] - CAMERA.position[1]
      @game.attron(Ncurses.COLOR_PAIR(4))
      @game.mvaddstr(position_y, position_x, entities[i].char)
      @game.attroff(Ncurses.COLOR_PAIR(4))
      if entities[i].crosshairs
        @game.attron(Ncurses.COLOR_PAIR(3))
        @game.mvaddstr(
          entities[i].crosshairs[1] - CAMERA.position[1],
          entities[i].crosshairs[0] - CAMERA.position[0],
          "+".to_s
        )
        @game.attroff(Ncurses.COLOR_PAIR(3))
      end
    end
  end

end

class Camera
  attr_accessor :position, :buffer_x, :buffer_y
  def initialize(buffer_x = 10, buffer_y = 10)
    @position = Vector[0,0]
    @buffer_x = buffer_x
    @buffer_y = buffer_y
  end

  def update()
    if PLAYER.position[0] - CAMERA.position[0] <= CAMERA.buffer_x
      CAMERA.position -= Vector[1,0]
    end
    if PLAYER.position[1] - CAMERA.position[1] <= CAMERA.buffer_x
      CAMERA.position -= Vector[0,1]
    end
    if GAME_WIDTH - PLAYER.position[0] + CAMERA.position[0] <= CAMERA.buffer_x
      CAMERA.position += Vector[1,0]
    end
    if GAME_HEIGHT - PLAYER.position[1] + CAMERA.position[1] <= CAMERA.buffer_x
      CAMERA.position += Vector[0,1]
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
    for y in 1...(200)
      for x in 1...(200)
        @terrain_hash[Vector[x,y]] = Tile.new(Vector[x,y])
      end
    end
  end

  def create_ground()
    for y in (GAME_HEIGHT / 2).floor...(GAME_HEIGHT + 1)
      for x in 1...(200)
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
    return true if (MAP[@position + Vector[1,0]].type !=0 ||
      MAP[@position - Vector[1,0]].type !=0) # Wall-adjacent
    return true if (MAP[@position + Vector[1,1]].type !=0 ||
      MAP[@position + Vector[-1,1]].type !=0) #Ledge
    return false # Mid-air or nil
  end

  def is_clear_above
    return false if MAP[@position + Vector[0, -1]] == nil
    return true if MAP[@position + Vector[0, -1]].is_navigable
    return false
  end

  def is_clear_below
    return false if MAP[@position + Vector[0, -1]] == nil
    return true if MAP[@position + Vector[0, 1]].is_navigable
    return false
  end

end

class Chunk
  attr_reader :position, :tiles
  def initialize(position)
    @position = position
    @tiles = {}
    create_tiles()
    create_default_chunk()
  end

  def create_tiles
    for y in CHUNK_HEIGHT
      for x in CHUNK_WIDTH
        @tiles[@position + Vector[x,y]] = Tile.new(@position + Vector[x,y])
      end
    end
  end

  def create_default_chunk
    for y in (CHUNK_HEIGHT / 2).floor...(CHUNK_HEIGHT + 1)
      for x in 1...(CHUNK_WIDTH + 1)
        if y == (CHUNK_HEIGHT / 2).floor
          @tiles[@position + Vector[x,y]].type = 1
        else
          @tiles[@position + Vector[x,y]].type = 2
        end
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
    @chunks[Vector[1,1]] = Chunk.new(Vector[1,1])
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
  attr_accessor :crosshairs, :inventory, :hotbar, :hotbar_active
  def initialize(position)
    super(position)
    @char = "☺".to_s
    while MAP[@position + Vector[0,1]].type == 0
      @position += Vector[0,1]
    end
    @crosshairs = @position + Vector[1,0]
    @inventory = Hash.new
    @hotbar_active = 1
    @hotbar = {
      1 => nil,
      2 => nil,
      3 => nil,
      4 => nil,
      5 => nil,
      6 => nil,
      7 => nil,
      8 => nil,
      9 => nil,
    }
  end

  def add_to_inventory(type)
    if @inventory[type] != nil
      @inventory[type] += 1
    else
      @hotbar.each do |k, v|
        if @hotbar[k] == nil
          @hotbar[k] = type
          break
        end
      end
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
      @hotbar.each do |k, v|
        if @hotbar[k] == type
          @hotbar[k] = nil
        end
      end
    end
  end

end

def handle_input(input)
  #if facing direction and valid navigable tile, go
  #else turn to face direction
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
    if PLAYER.crosshairs == PLAYER.position - Vector[1,0] 
      if MAP[PLAYER.crosshairs].is_navigable
        PLAYER.position -= Vector[1,0]
        PLAYER.crosshairs -= Vector[1,0]
      elsif MAP[PLAYER.crosshairs].is_clear_above
        PLAYER.position -= Vector[1,1]
        PLAYER.crosshairs -= Vector[1,1]
      elsif MAP[PLAYER.crosshairs].is_clear_below
        PLAYER.position -= Vector[1,-1]
        PLAYER.crosshairs -= Vector[1,-1]
      end
    else
      PLAYER.crosshairs = PLAYER.position - Vector[1,0]
    end

  when input == KEYS['d']
    if PLAYER.crosshairs == PLAYER.position + Vector[1,0] 
      if MAP[PLAYER.crosshairs].is_navigable
        PLAYER.position += Vector[1,0]
        PLAYER.crosshairs += Vector[1,0]
      elsif MAP[PLAYER.crosshairs].is_clear_above
        PLAYER.position += Vector[1,-1]
        PLAYER.crosshairs += Vector[1,-1]
      elsif MAP[PLAYER.crosshairs].is_clear_below
        PLAYER.position += Vector[1,1]
        PLAYER.crosshairs += Vector[1,1]
      end
    else
      PLAYER.crosshairs = PLAYER.position + Vector[1,0]
    end
  
  when input == KEYS['e']
    if MAP[PLAYER.crosshairs].type != 0
      PLAYER.add_to_inventory(MAP[PLAYER.crosshairs].type)
      MAP[PLAYER.crosshairs].type = 0
    end

  when input == KEYS['q']
    if PLAYER.inventory[PLAYER.hotbar[PLAYER.hotbar_active]] == nil
      return
    end
    if MAP[PLAYER.crosshairs].type == 0
      MAP[PLAYER.crosshairs].type = PLAYER.hotbar[PLAYER.hotbar_active]
      PLAYER.remove_from_inventory(PLAYER.hotbar[PLAYER.hotbar_active])
      
    end
  when input.between?(49,57)
    # Manages inventory slots
    # ASCII codes for 1-9 are 49-57
    PLAYER.hotbar_active = input - 48
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
  Ncurses.init_pair(99, Ncurses::COLOR_RED, Ncurses::COLOR_RED) # DEBUG COLOR
  Ncurses.init_pair(0, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(1, Ncurses::COLOR_GREEN, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(2, Ncurses::COLOR_BLACK, Ncurses::COLOR_WHITE)
  Ncurses.init_pair(3, Ncurses::COLOR_RED, Ncurses::COLOR_BLACK)
  Ncurses.init_pair(4, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK)

  GAME_HEIGHT = (Ncurses.LINES() * 0.8).floor - 2
  GAME_WIDTH = Ncurses.COLS() - 2
  CHUNK_HEIGHT = 200
  CHUNK_WIDTH = 200
  ENTITIES = []
  KEYS = {
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
  }
  TILES = [
    " ".to_s, # 0
    "░".to_s, # 1
    "░".to_s, # 2
  ]

  
  window_manager = WindowManager.new()
  terrain = Terrain.new()
  terrain.create_ground
  MAP = terrain.terrain_hash
  PLAYER = Player.new(Vector[50,10])
  CAMERA = Camera.new
  window_manager.draw_terrain
  window_manager.draw_entities(ENTITIES)
  window_manager.hud_message("Press esc to quit")
  window_manager.to_virtual_screen
  Ncurses.doupdate()

  # main game loop
  input = 0
  Ncurses.curs_set(0)
  while(input != KEYS['ESC'])
    CAMERA.update
    window_manager.erase_windows()
    handle_input(input)
    window_manager.draw_terrain
    
    window_manager.draw_entities(ENTITIES)
    window_manager.hud_message("Camera: ("+CAMERA.position[0].to_s+
    ", "+CAMERA.position[1].to_s+")")
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


