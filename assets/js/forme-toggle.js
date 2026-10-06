// VGC 샘플 카드: [data-forme-toggle] 버튼으로 메가 폼 ⇄ 기본 폼을 바꾼다 (이름·타입·특성).
(() => {
  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-forme-toggle]");
    const card = button?.closest(".c--sdCard");
    if (!card) return;
    const mega = card.dataset.forme !== "mega";
    card.dataset.forme = mega ? "mega" : "base";
    button.setAttribute("aria-pressed", String(mega));
  });
})();
