// 복사 기능.
//  1) [data-copy-text] 버튼: 그 값을 그대로 클립보드에 넣는다.
//  2) 원문 복사: 화면 표시와 복사 결과가 다른 "원자"(샘플 카드의 복사 블록)는
//     선택 범위가 조금만 걸쳐도 원자 전체의 원문으로 바꿔 넣는다. 나머지 글자는 그대로 이어 붙인다.
(() => {
  const text = JSON.parse(document.getElementById("site-text")?.textContent || "{}");
  const label = (key) => key.split(".").reduce((value, part) => value?.[part], text) || key;

  // ── 클립보드 쓰기와 버튼 피드백 ──
  async function writeClipboard(value) {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(value);
      return;
    }
    const area = document.createElement("textarea");
    area.value = value;
    area.setAttribute("readonly", "");
    area.style.cssText = "position:fixed;opacity:0;pointer-events:none";
    document.body.append(area);
    area.select();
    const ok = document.execCommand("copy");
    area.remove();
    if (!ok) throw new Error("copy command failed");
  }

  function announce(message) {
    const region = document.querySelector("[data-live-region]");
    if (!region) return;
    region.textContent = "";
    setTimeout(() => { region.textContent = message; }, 30);
  }

  function flash(button, ok) {
    button.dataset.copied = String(ok);
    clearTimeout(button.copyTimer);
    button.copyTimer = setTimeout(() => { delete button.dataset.copied; }, 1600);
  }

  async function copyFrom(button, value) {
    try {
      await writeClipboard(value);
      flash(button, true);
      announce(label("copy.done"));
    } catch (e) {
      flash(button, false);
      announce(label("copy.failed"));
    }
  }

  // ── 원문 복사: 형식(원자) 등록 ──
  const formats = [];
  function registerFormat(selector, extract, { block = false } = {}) {
    formats.push({ selector, extract, block });
  }
  const atomSelector = () => formats.map((f) => f.selector).join(", ");

  // 가장 바깥 원자를 찾는다
  function outermostAtom(node) {
    const element = node.nodeType === 1 ? node : node.parentElement;
    let atom = element?.closest(atomSelector()) || null;
    while (atom?.parentElement?.closest(atomSelector())) atom = atom.parentElement.closest(atomSelector());
    return atom;
  }
  const formatOf = (element) => formats.find((f) => element.matches(f.selector));

  const isBlock = (element) => !/^(inline|contents|none)/.test(getComputedStyle(element).display);
  const isHidden = (element) => getComputedStyle(element).display === "none";

  function serialize(range) {
    // 원자의 원문은 토큰으로 빼 두고, 일반 글자만 공백·줄바꿈을 정리한 뒤 되돌려 넣는다
    // (Showdown 원문은 한 글자도 바뀌면 안 된다).
    const atoms = [];
    let out = "";
    const atLineStart = () => out === "" || out.endsWith("\n");
    const newline = () => { if (!atLineStart()) out += "\n"; };
    const visit = (node) => {
      if (!range.intersectsNode(node)) return;
      if (node.nodeType === 3) {
        let value = node.data;
        if (node === range.endContainer) value = value.slice(0, range.endOffset);
        if (node === range.startContainer) value = value.slice(range.startOffset);
        if (getComputedStyle(node.parentElement).whiteSpace.startsWith("pre")) {
          out += value;
        } else if (value.trim() || !atLineStart()) {
          out += value.replace(/\s+/g, " "); // 블록 사이의 공백뿐인 글자는 건너뛴다
        }
        return;
      }
      if (node.nodeType !== 1 || isHidden(node)) return;
      const format = node.matches(atomSelector()) ? formatOf(node) : null;
      if (format) {
        if (format.block) newline();
        out += `\uE000${atoms.push(format.extract(node)) - 1}\uE001`;
        if (format.block) out += "\n";
        return;
      }
      const block = isBlock(node);
      if (block) newline();
      node.childNodes.forEach(visit);
      if (block) newline();
    };
    const root = range.commonAncestorContainer;
    visit(root.nodeType === 1 ? root : root.parentElement);
    return out
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n[ \t]+/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim()
      .replace(/\uE000(\d+)\uE001/g, (_, index) => atoms[Number(index)]);
  }

  document.addEventListener("copy", (event) => {
    const selection = document.getSelection();
    if (!selection || selection.isCollapsed || !formats.length) return;
    if (event.target.closest?.("input, textarea, [contenteditable]")) return;
    const range = selection.getRangeAt(0);
    const inside = outermostAtom(range.commonAncestorContainer);
    let value;
    if (inside) {
      value = formatOf(inside).extract(inside); // 원자 하나 안에서만 고른 경우
    } else {
      const touched = [...document.querySelectorAll(atomSelector())].some((atom) => range.intersectsNode(atom));
      if (!touched) return; // 일반 글자만 고르면 브라우저 기본 복사
      value = serialize(range);
    }
    event.clipboardData.setData("text/plain", value);
    event.preventDefault();
  });

  // ── 기본 형식 ──
  const blockSource = (block) => block.querySelector("[data-copy-src]").textContent;
  registerFormat(".c--copyBlock", blockSource, { block: true });

  // ── 버튼 ──
  document.addEventListener("click", (event) => {
    const textButton = event.target.closest("[data-copy-text]");
    if (textButton) {
      copyFrom(textButton, textButton.dataset.copyText);
      return;
    }
    const blockButton = event.target.closest("[data-copy-block]");
    const block = blockButton?.closest(".c--copyBlock");
    if (block) copyFrom(blockButton, blockSource(block));
  });
})();
