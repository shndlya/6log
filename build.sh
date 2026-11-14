#!/usr/bin/env bash
# 6log build: content/posts/*.md -> site/
# requires: pandoc (see flake.nix devShell)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "error: pandoc not found — run 'nix develop' first" >&2
  exit 1
fi

OUT="$ROOT/site"

rm -rf "$OUT"
mkdir -p "$OUT/posts"
cp static/style.css static/htmx.min.js "$OUT/"

# --- helpers -------------------------------------------------------------

escape_sed() {
  sed -e 's/[&/\\]/\\&/g'
}

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

HX='hx-get="%s" hx-push-url="true" hx-target="#main" hx-select="#main" hx-swap="outerHTML"'

crumb_home_link() {
  printf '<a href="/" '"$HX"' >home</a>' "/"
}

site_header() {
  printf '<header class="site-header"><a class="site-mark" href="/" '"$HX"' >6log</a></header>\n' "/"
}

# --- collect post metadata ------------------------------------------------
# meta.txt renders one line per post: pinned|date|category|title|slug|src

META="$(mktemp)"
for f in content/posts/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .md)"
  slug="${base#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}"
  pandoc "$f" -f markdown+yaml_metadata_block \
    --template=templates/meta.txt \
    --metadata="slug:$slug" \
    --metadata="src:$f" \
    --wrap=none >> "$META"
done

pinned="$({ awk -F'|' '$1=="p"' "$META" || true; } | sort -t'|' -k2,2r)"
new="$({ awk -F'|' '$1=="-"' "$META" || true; } | sort -t'|' -k2,2r)"
computers="$({ awk -F'|' '$3=="computers"' "$META" || true; } | sort -t'|' -k2,2r)"
learning="$({ awk -F'|' '$3=="learning"' "$META" || true; } | sort -t'|' -k2,2r)"
entertainment="$({ awk -F'|' '$3=="entertainment"' "$META" || true; } | sort -t'|' -k2,2r)"
notes="$({ awk -F'|' '$3=="notes"' "$META" || true; } | sort -t'|' -k2,2r)"
photos="$({ awk -F'|' '$3=="photos"' "$META" || true; } | sort -t'|' -k2,2r)"
all="$({ cat "$META" || true; } | sort -t'|' -k2,2r)"
rm -f "$META"

# --- shared snippets --------------------------------------------------------

row() { # date title slug category — columns: date (center), title (left), tag (center, last)
  local date="$1" title="$2" slug="$3" category="$4"
  local d t url
  d="$(printf '%s' "$date" | html_escape)"
  t="$(printf '%s' "$title" | html_escape)"
  url="/posts/$slug.html"
  printf '<tr><td class="t-date"><time datetime="%s">%s</time></td><td class="t-title"><a href="%s" '"$HX"' >%s</a></td><td class="t-tag"><span class="cat cat-%s">%s</span></td></tr>\n' \
    "$d" "$d" "$url" "$url" "$t" "$category" "$category"
}

render_table() { # lines
  if [ -n "$1" ]; then
    echo "$1" | while IFS='|' read -r p date cat title slug src; do
      [ -n "$src" ] || continue
      row "$date" "$title" "$slug" "$cat"
    done
  else
    printf '<tr><td colspan="3" class="empty">nothing here yet</td></tr>\n'
  fi
}

render_index() { # lines — the Index mega-table: date (center), category (center), title (left)
  if [ -n "$1" ]; then
    echo "$1" | while IFS='|' read -r p date cat title slug src; do
      [ -n "$src" ] || continue
      local d t url
      d="$(printf '%s' "$date" | html_escape)"
      t="$(printf '%s' "$title" | html_escape)"
      url="/posts/$slug.html"
      printf '<tr><td class="t-date"><time datetime="%s">%s</time></td><td class="t-tag"><span class="cat cat-%s">%s</span></td><td class="t-title"><a href="%s" '"$HX"' >%s</a></td></tr>\n' \
        "$d" "$d" "$cat" "$cat" "$url" "$url" "$t"
    done
  else
    printf '<tr><td colspan="3" class="empty">nothing here yet</td></tr>\n'
  fi
}

home_section() { # category key, page path, title, lines — clickable title + full table
  local key="$1" path="$2" title="$3" lines="$4" url
  url="$path.html"
  printf '<h2 class="section-title"><span class="bullet d-%s" aria-hidden="true">■</span><a href="%s" '"$HX"' >%s</a></h2>\n' \
    "$key" "$url" "$url" "$title"
  printf '<table class="posts">\n    <tbody>\n'
  render_table "$lines"
  printf '    </tbody>\n  </table>\n'
}

# --- index page -------------------------------------------------------------

{
  sed "s/__TITLE__/6log/" templates/head.html
  cat <<'EOF'
<main id="main" class="home" data-title="6log" data-breadcrumb="home">

  <h1 class="site-mark">6log</h1>
  <section class="about-grid">
    <div class="about-col">
      <p class="about-note">Kunal Shandilya's blog. Contact options:</p>
      <div class="contact-grid">
        <a class="contact-instagram" href="https://instagram.com/shndlya" target="_blank" rel="noopener" aria-label="Instagram"
          ><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="0.8" fill="currentColor" stroke="none"/></svg
        ></a>
        <a class="contact-email" href="mailto:shndlya@proton.me" aria-label="Email shndlya@proton.me"
          ><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="m4 7 8 6 8-6"/></svg
        ></a>
      </div>
    </div>
  </section>

  <hr class="section-rule">

  <div class="tables-row">
    <section>
EOF
  home_section pinned pinned "Pinned" "$pinned"
  cat <<'EOF'
    </section>
    <section>
EOF
  home_section new new "New" "$new"
  cat <<'EOF'
    </section>
  </div>

  <section>
EOF
  home_section computers computers "Computers" "$computers"
  echo '  </section>'
  echo '  <section>'
  home_section entertainment entertainment "Entertainment" "$entertainment"
  echo '  </section>'
  echo '  <section>'
  home_section photos photos "Photos" "$photos"
  cat <<'EOF'
  </section>
  <section>
EOF
  home_section learning learning "Learning" "$learning"
  cat <<'EOF'
  </section>
  <section>
EOF
  home_section notes notes "Notes" "$notes"
  cat <<'EOF'
  </section>

</main>
EOF
  cat templates/footer.html
} > "$OUT/index.html"

# --- category pages (full-page single table) --------------------------------

cat_page() { # category key, page path, title, lines
  local key="$1" path="$2" title="$3" lines="$4"
  local t_esc crumb
  t_esc="$(printf '%s' "$title" | html_escape)"
  crumb="$(crumb_home_link)/<span class=\"crumb-current\">$t_esc</span>"
  {
    sed "s/__TITLE__/$(printf '%s' "$t_esc" | escape_sed)/" templates/head.html
    printf '<main id="main" class="list" data-title="%s" data-breadcrumb="home/%s">\n\n' "$t_esc" "$t_esc"
    site_header
    printf '  <h2 class="section-title"><span class="bullet d-%s" aria-hidden="true">■</span>%s</h2>\n  <table class="posts">\n    <tbody>\n' \
      "$key" "$t_esc"
    render_table "$lines"
    printf '    </tbody>\n  </table>\n\n</main>\n'
    cat templates/footer.html
  } > "$OUT/$path.html"
}

cat_page pinned pinned "Pinned" "$pinned"
cat_page new new "New" "$new"
cat_page computers computers "Computers" "$computers"
cat_page learning learning "Learning" "$learning"
cat_page entertainment entertainment "Entertainment" "$entertainment"
cat_page notes notes "Notes" "$notes"
cat_page photos photos "Photos" "$photos"

# --- index page (mega-table of every post ever published) --------------------

{
  sed "s/__TITLE__/Index/" templates/head.html
  crumb="$(crumb_home_link)/<span class=\"crumb-current\">Index</span>"
  printf '<main id="main" class="list" data-title="Index" data-breadcrumb="home/Index">\n\n'
  site_header
  printf '  <h2 class="section-title">Index</h2>\n  <table class="posts">\n    <tbody>\n'
  render_index "$all"
  printf '    </tbody>\n  </table>\n\n</main>\n'
  cat templates/footer.html
} > "$OUT/all.html"

# --- post pages --------------------------------------------------------------

{
  printf '%s\n' "$pinned"
  printf '%s\n' "$new"
  printf '%s\n' "$computers"
  printf '%s\n' "$learning"
  printf '%s\n' "$entertainment"
  printf '%s\n' "$notes"
  printf '%s\n' "$photos"
} | while IFS='|' read -r p date cat title slug src; do
  [ -n "$src" ] || continue
  title_esc="$(printf '%s' "$title" | html_escape)"
  crumb="$(crumb_home_link)/<span class=\"crumb-current\">$title_esc</span>"
  {
    sed "s/__TITLE__/$(printf '%s' "$title_esc" | escape_sed)/" templates/head.html
    pandoc "$src" -f markdown+yaml_metadata_block \
      --template=templates/article.html \
      --shift-heading-level-by=1 \
      --wrap=none
    cat templates/footer.html
  } > "$OUT/posts/$slug.html"
done

echo "built $OUT ($(find "$OUT" -type f | wc -l) files)"
