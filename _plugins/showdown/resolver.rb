# frozen_string_literal: true

module Pokedex
  # Showdown의 toID: 소문자 영숫자만 남긴다 (Flabébé → flabebe: 악센트는 떼고 남긴다)
  def self.to_id(text)
    text.to_s.unicode_normalize(:nfd).downcase.gsub(/[^a-z0-9]/, "")
  end
end

# 파싱한 샘플을 카드용 데이터(한국어 이름·타입·성격 보정·능력치 행)로 바꾼다.
# 종 이름: overrides → 사전 → 규칙 순으로 채운다.
#   메가: 메가 + 기본 이름(+X/Y) / 지역·성별 등 폼: 기본 이름(폼 이름) — 폼 이름은 overrides.yml의 formes, 없으면 사전의 폼 번역
#   모습만 다른 폼(비비용 무늬, 플라제스 꽃 색 등 — 사전의 cosmetic)은 기본 이름만 쓴다.
# 영어로 남은 이름은 missing에 모아 빌드 경고로 알린다.
module Showdown
  class Resolver
    STAT_KEYS = %w[hp atk def spa spd spe].freeze
    HABCDS = %w[H A B C D S].freeze
    # 성격 → [올리는 능력치, 내리는 능력치] (무보정 성격은 없음)
    NATURES = {
      "Adamant" => %w[atk spa], "Bold" => %w[def atk], "Brave" => %w[atk spe], "Calm" => %w[spd atk],
      "Careful" => %w[spd spa], "Gentle" => %w[spd def], "Hasty" => %w[spe def], "Impish" => %w[def spa],
      "Jolly" => %w[spe spa], "Lax" => %w[def spd], "Lonely" => %w[atk def], "Mild" => %w[spa def],
      "Modest" => %w[spa atk], "Naive" => %w[spe spd], "Naughty" => %w[atk spd], "Quiet" => %w[spa spe],
      "Rash" => %w[spa spd], "Relaxed" => %w[def spe], "Sassy" => %w[spd spe], "Timid" => %w[spe atk],
    }.freeze

    def initialize(dex, stat_labels: "habcds")
      @dex = dex
      @stat_labels = stat_labels
      @overrides = dex["overrides"] || {}
      # 메가스톤 → 메가 폼들 (냐오닉스 수컷·암컷, 싸리용 세 모습처럼 같은 돌을 여러 폼이 쓴다)
      @megas_by_item = (dex["species"] || {}).each_with_object(Hash.new { |h, k| h[k] = [] }) do |(id, row), map|
        map[row["required_item"]] << id if row["required_item"] && row["forme"].to_s.split("-").include?("Mega")
      end
    end

    def resolve(set)
      @missing = []
      species_id = Pokedex.to_id(set.species)
      item_id = Pokedex.to_id(set.item)
      mega_id = mega_for(species_id, item_id)

      # 별명·성별·이로치는 카드에 표시하지 않는다 (복사되는 원문에는 그대로 남음)
      {
        "base" => form(species_id, set.species, ability: set.ability),
        "mega" => (form(mega_id, species_row(mega_id)["name"]) if mega_id),
        "item" => (item_name(item_id, set.item) if set.item),
        "nature" => (names("natures")[set.nature] || set.nature if set.nature),
        "stats" => stats(set), # 챔피언스의 SP(0~32)도 Showdown은 EVs 줄에 적는다
        "stats_kind" => "SP",
        "moves" => set.moves.map { |move| move_row(move) },
        "missing" => @missing.uniq,
      }
    end

    private

    def species_row(id)
      (@dex["species"] || {})[id] || {}
    end

    def base_id(id)
      species_row(id)["base"] || id
    end

    # 이 종이 이 도구로 메가진화하는 폼. 같은 돌을 쓰는 폼이 여럿이면 지금 폼에 맞는 것("F" → "F-Mega")
    def mega_for(species_id, item_id)
      candidates = @megas_by_item.fetch(item_id, []).select { |id| species_row(id)["base"] == base_id(species_id) }
      return candidates.first if candidates.size <= 1

      row = species_row(species_id)
      forme = row["forme"] || species_row(base_id(species_id))["base_forme"]
      candidates.find { |id| species_row(id)["forme"] == "#{forme}-Mega" } || candidates.first
    end


    def names(table)
      (@dex["names"] || {})[table] || {}
    end

    def form(id, english, ability: nil)
      row = species_row(id)
      row = species_row(row["base"]) if row["types"].nil? && row["base"] # 모습만 다른 폼은 사전에 타입·특성이 없다
      ability ||= row.dig("abilities", "0")
      {
        "name" => species_name(id, english),
        "types" => Array(row["types"]).map { |t| type(t) },
        "ability" => (lookup("abilities", Pokedex.to_id(ability), ability) if ability),
      }
    end

    def species_name(id, english)
      row = species_row(id)
      return @overrides.dig("species", id) if @overrides.dig("species", id)
      return row["ko"] if row["ko"]

      base = @overrides.dig("species", row["base"]) || species_row(row["base"])["ko"] if row["base"]
      forme = row["forme"].to_s
      forme_ko = row["forme_ko"]&.tr("（）", "()")
      if base
        return "메가#{base}#{forme.delete_prefix('Mega').delete_prefix('-')}" if forme.start_with?("Mega")
        return forme_ko if forme_ko&.start_with?("메가") # "메가냐오닉스(수컷의 모습)"
        return base if row["cosmetic"] # 모습만 다른 폼 (사전을 만들 때 판정)

        label = @overrides.dig("formes", forme) || forme_ko&.sub(/\A(.+)\((.+)\)\z/, '\1·\2')
        return "#{base}(#{label})" if label
      end

      @missing << english
      base ? "#{base} (#{forme})" : english
    end

    def item_name(id, english)
      return @overrides.dig("items", id) if @overrides.dig("items", id)

      ko = (@dex["items"] || {}).dig(id, "ko")
      return ko if ko

      mega = @megas_by_item.fetch(id, []).first
      if mega
        row = species_row(mega)
        base = @overrides.dig("species", row["base"]) || species_row(row["base"])["ko"]
        suffix = row["forme"].to_s.start_with?("Mega") ? row["forme"].delete_prefix("Mega").delete_prefix("-") : ""
        return "#{base}나이트#{suffix}" if base
      end
      @missing << english
      english
    end

    def lookup(table, id, english)
      @overrides.dig(table, id) || (@dex[table] || {}).dig(id, "ko") || (@missing << english && english)
    end

    def type(english)
      { "ko" => names("types")[english] || english, "id" => Pokedex.to_id(english) }
    end

    def move_row(english)
      row = (@dex["moves"] || {})[Pokedex.to_id(english)] || {}
      type_en = row["type"] || "Normal"
      { "name" => lookup("moves", Pokedex.to_id(english), english), "type" => Pokedex.to_id(type_en),
        "type_ko" => names("types")[type_en] || type_en }
    end

    # 막대는 SP 기준 32칸
    def stats(set)
      plus, minus = NATURES[set.nature]
      labels = @stat_labels == "ko" ? STAT_KEYS.map { |k| names("stats")[k] || k } : HABCDS
      STAT_KEYS.each_with_index.map do |key, index|
        value = set.evs[key].to_i
        mod = ("plus" if key == plus) || ("minus" if key == minus)
        bar = (value.clamp(0, 32) * 100.0 / 32).round(2)
        { "label" => labels[index], "value" => value, "mod" => mod,
          "bar" => bar == bar.to_i ? bar.to_i : bar } # 막대 길이 % (정수면 100, 아니면 6.25)
      end
    end
  end
end
