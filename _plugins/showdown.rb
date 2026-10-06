# frozen_string_literal: true

require_relative "showdown/parser"
require_relative "showdown/resolver"

# 샘플 카드: {% showdown %}…Showdown 텍스트…{% endshowdown %} (포켓몬 챔피언스 형식: 노력치는 SP 0~32)
#   샘플(빈 줄로 구분)마다 카드 하나를 그리고, 복사하면 붙여 넣은 영어 원문이 그대로 나온다.
# 팀 정보: 글을 읽을 때 글 안의 샘플을 모두 모아 page.team(요약 카드)과 page.team_source(팀 전체 원문)를 만든다.
module ShowdownPlugin
  module_function

  def resolver(site)
    dex = site.data["pokedex"] || {}
    labels = site.config.dig("showdown", "stat_labels") || "habcds"
    @cache ||= {}
    @cache[[dex.object_id, labels]] ||= Showdown::Resolver.new(dex, stat_labels: labels)
  end

  def blocks(content)
    content.to_s.scan(/\{%-?\s*showdown[^%]*%\}(.*?)\{%-?\s*endshowdown\s*-?%\}/m).flatten
  end

  class Block < Liquid::Block
    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]
      counter = (context.registers[:sd_counter] ||= Hash.new(0))
      Showdown::Parser.parse(super).map do |set|
        card = ShowdownPlugin.resolver(site).resolve(set)
        card["missing"].each do |name|
          Jekyll.logger.warn("Showdown:", "#{page&.[]('path')}: 한국어 이름 없음 — #{name} (_data/pokedex/overrides.yml에 추가)")
        end
        counter[page&.[]("path")] += 1
        context.stack do
          context["sd_card"] = card
          context["sd_id"] = "sample-#{counter[page&.[]('path')]}"
          context["sd_html"] = Liquid::Template.parse("{% include sample-card.html card=sd_card %}").render!(context)
          context["sd_source"] = set.source
          Liquid::Template.parse('{% include copy-block.html format="showdown" id=sd_id source=sd_source html=sd_html %}')
                          .render!(context).strip
        end
      end.join("\n\n")
    end
  end

  Jekyll::Hooks.register :site, :post_read do |site|
    site.posts.docs.each do |post|
      team = []
      sources = []
      blocks(post.content).each do |body|
        Showdown::Parser.parse(body).each do |set|
          card = resolver(site).resolve(set)
          form = card["mega"] || card["base"]
          team << { "id" => "sample-#{team.size + 1}", "name" => card["base"]["name"], "mega" => !card["mega"].nil?,
                    "types" => form["types"], "item" => card["item"] }
          sources << set.source
        end
      end
      next if team.empty?

      post.data["team"] = team
      post.data["team_source"] = sources.join("\n\n")
    end
  end
end

Liquid::Template.register_tag("showdown", ShowdownPlugin::Block)
