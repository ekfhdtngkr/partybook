// 파티 목록 태그 필터: 태그 버튼을 누르면 그 태그가 있는 글만 보인다. 주소의 ?tag= 로도 고를 수 있다.
(() => {
  const buttons = [...document.querySelectorAll("[data-filter]")];
  const cards = [...document.querySelectorAll(".c--partyCard")];
  if (!buttons.length) return;

  const apply = (tag) => {
    buttons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.filter === tag)));
    cards.forEach((card) => {
      card.hidden = tag !== "" && !card.dataset.tags.split("|").includes(tag);
    });
  };

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-filter]");
    if (!button) return;
    const tag = button.dataset.filter;
    apply(tag);
    const url = new URL(location.href);
    tag ? url.searchParams.set("tag", tag) : url.searchParams.delete("tag");
    history.replaceState(null, "", url);
  });

  const initial = new URLSearchParams(location.search).get("tag") || "";
  apply(buttons.some((b) => b.dataset.filter === initial) ? initial : "");
})();
