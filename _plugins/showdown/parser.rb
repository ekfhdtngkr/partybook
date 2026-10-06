# frozen_string_literal: true

# Showdown 내보내기 텍스트 파서. 빈 줄로 구분된 여러 샘플을 읽고, 샘플마다 원문(source)도 그대로 남긴다.
#   별명 (종) (F) @ 도구 / Ability: / Level: / Shiny: / Tera Type: / EVs: / IVs: / ~ Nature / - 기술
module Showdown
  Set = Struct.new(:source, :nickname, :species, :gender, :item, :ability, :level, :shiny, :tera,
                   :evs, :ivs, :nature, :moves, keyword_init: true)

  module Parser
    module_function

    STATS = { "hp" => "hp", "atk" => "atk", "def" => "def", "spa" => "spa", "spd" => "spd", "spe" => "spe" }.freeze

    def parse(text)
      blocks = text.to_s.gsub("\r\n", "\n").split(/\n\s*\n/).map(&:strip).reject(&:empty?)
      blocks.map { |block| parse_set(block) }
    end

    def parse_set(block)
      lines = block.lines.map(&:strip).reject(&:empty?)
      set = Set.new(source: lines.join("\n"), level: nil, shiny: false, evs: {}, ivs: {}, moves: [])
      read_first_line(set, lines.shift)
      lines.each { |line| read_line(set, line) }
      set
    end

    def read_first_line(set, line)
      name, item = line.split(" @ ", 2)
      set.item = item&.strip
      name = name.strip
      if (match = name.match(/\s\((M|F)\)\z/))
        set.gender = match[1]
        name = name[0...match.begin(0)].strip
      end
      if (match = name.match(/\A(.+)\s\(([^()]+)\)\z/))
        set.nickname = match[1].strip
        set.species = match[2].strip
      else
        set.species = name
      end
    end

    def read_line(set, line)
      case line
      when /\AAbility:\s*(.+)\z/ then set.ability = Regexp.last_match(1)
      when /\ALevel:\s*(\d+)\z/ then set.level = Regexp.last_match(1).to_i
      when /\AShiny:\s*Yes\z/i then set.shiny = true
      when /\ATera Type:\s*(.+)\z/ then set.tera = Regexp.last_match(1)
      when /\AEVs:\s*(.+)\z/ then set.evs = read_spread(Regexp.last_match(1))
      when /\AIVs:\s*(.+)\z/ then set.ivs = read_spread(Regexp.last_match(1))
      when /\A(\w+) Nature\z/ then set.nature = Regexp.last_match(1)
      when /\A[-~]\s*(.+)\z/ then set.moves << Regexp.last_match(1)
      end
    end

    # "2 HP / 32 SpA / 32 Spe" → { "hp" => 2, "spa" => 32, "spe" => 32 }
    def read_spread(text)
      text.split("/").each_with_object({}) do |part, spread|
        value, stat = part.strip.split(/\s+/, 2)
        key = STATS[stat.to_s.downcase]
        spread[key] = value.to_i if key
      end
    end
  end
end
