// 글 목차: 지금 읽는 제목을 목차에서 강조하고(aria-current), 목차가 상자 안에서 스크롤될 만큼 길면
// 강조한 항목이 목차 상자 안에 보이도록 상자만 스크롤한다 (페이지는 움직이지 않음).
(() => {
  const toc = document.querySelector(".c--party_toc");
  if (!toc) return;
  const links = [...toc.querySelectorAll('a[href^="#"]')];
  const headings = links.map((a) => document.getElementById(decodeURIComponent(a.hash.slice(1)))).filter(Boolean);
  if (!headings.length) return;
  let current = null;

  const keepInView = (link) => {
    if (toc.scrollHeight <= toc.clientHeight) return;
    const box = toc.getBoundingClientRect();
    const item = link.getBoundingClientRect();
    const margin = 48;
    if (item.top < box.top + margin) toc.scrollTop -= box.top + margin - item.top;
    else if (item.bottom > box.bottom - margin) toc.scrollTop += item.bottom - (box.bottom - margin);
  };

  const update = () => {
    const line = (document.querySelector(".c--siteHeader")?.offsetHeight || 64) + 32; // 머리글 바로 아래 기준선
    let index = 0;
    headings.forEach((heading, i) => { if (heading.getBoundingClientRect().top <= line) index = i; });
    // 페이지 끝: 마지막 제목이 기준선까지 못 올라와도 마지막 항목을 강조
    if (innerHeight + scrollY >= document.documentElement.scrollHeight - 2) index = headings.length - 1;
    const link = links[index];
    if (link === current) return;
    current?.removeAttribute("aria-current");
    link.setAttribute("aria-current", "location");
    current = link;
    keepInView(link);
  };

  // 제목 수십 개의 위치만 읽으므로 스크롤마다 바로 갱신해도 가볍다
  addEventListener("scroll", update, { passive: true });
  addEventListener("resize", update);
  update();
})();
