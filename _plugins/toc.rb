# frozen_string_literal: true

require "nokogiri"

# 목차: 본문의 h2·h3에 읽을 수 있는 id(한글 유지)를 다시 붙이고 목차 항목을 만든다.
# kramdown의 자동 id는 한글 제목을 section-1처럼 만들기 때문이다.
#   {{ content | with_heading_ids }}   {% assign toc = content | toc_items %}
module Toc
  module_function

  def slug(text)
    value = text.downcase.gsub(/[^\p{L}\p{N}\s-]/u, "").strip.gsub(/[\s-]+/, "-")
    value.empty? ? "section" : value
  end

  def process(html)
    seen = Hash.new(0)
    items = []
    fragment = Nokogiri::HTML5::DocumentFragment.parse(html.to_s)
    fragment.css("h2, h3").each do |heading|
      next if heading.ancestors(".c--copyBlock").any? # 샘플 카드 등 복사 블록 안의 제목은 목차에 넣지 않는다
      base = slug(heading.text)
      seen[base] += 1
      id = seen[base] == 1 ? base : "#{base}-#{seen[base]}"
      heading["id"] = id
      items << { id: id, text: heading.text.strip, level: heading.name[1].to_i }
    end
    [fragment.to_html(encoding: "UTF-8"), items]
  end

  module Filters
    def with_heading_ids(html)
      Toc.process(html)[0]
    end

    def toc_items(html)
      Toc.process(html)[1].map { |item| item.transform_keys(&:to_s) }
    end
  end
end

Liquid::Template.register_filter(Toc::Filters)
