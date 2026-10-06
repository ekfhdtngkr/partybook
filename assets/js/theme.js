// 화면 모드 토글: 라이트 / 다크 / 시스템. 첫 적용은 <head>의 인라인 스크립트가 한다.
(() => {
  const root = document.documentElement;
  const media = matchMedia("(prefers-color-scheme: dark)");

  function apply(pref) {
    const dark = pref === "dark" || (pref === "system" && media.matches);
    root.setAttribute("data-theme", dark ? "dark" : "light");
    root.setAttribute("data-theme-pref", pref);
    for (const button of document.querySelectorAll("[data-theme-choice]")) {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === pref));
    }
  }

  function remember(pref) {
    try {
      if (pref === "system") localStorage.removeItem("theme");
      else localStorage.setItem("theme", pref);
    } catch (e) {
      /* 저장소를 못 쓰는 환경이어도 이번 화면에는 적용한다 */
    }
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest("[data-theme-choice]");
    if (!button) return;
    remember(button.dataset.themeChoice);
    apply(button.dataset.themeChoice);
  });

  media.addEventListener("change", () => {
    if (root.getAttribute("data-theme-pref") === "system") apply("system");
  });

  apply(root.getAttribute("data-theme-pref") || "system");
})();
