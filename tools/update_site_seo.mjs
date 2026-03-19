#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const DOCS = path.join(ROOT, "docs");
const BASE_URL = "https://caisi.dev";
const SITE_NAME = "CAISI";
const ORG_NAME = "Centre for AI Security and Integrity (CAISI)";
const GENERIC_IMAGE = `${BASE_URL}/assets/caisi-social.png`;
const LOGO_IMAGE = `${BASE_URL}/assets/caisi-logo.png`;
const AUTHOR_PROFILE = `${BASE_URL}/authors/david-ahmann/`;
const AUTHOR_IMAGE = `${BASE_URL}/assets/david-ahmann-headshot.png`;

const PAGE_TYPES = {
  home: "home",
  report: "report",
  collection: "collection",
  article: "article",
  profile: "profile",
};

const COLLECTION_ROUTES = new Set([
  "/blog/",
  "/blog/operating-notes/",
  "/blog/openclaw/",
  "/blog/sprawl-2026/",
  "/blog/wrkr/",
  "/blog/gait/",
  "/blog/control-benchmarks/",
  "/blog/governed-adoption/",
  "/research/",
]);

function walk(dir) {
  const files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walk(full));
    if (entry.isFile() && entry.name === "index.html") files.push(full);
  }
  return files;
}

function fileToRoute(file) {
  const rel = path.relative(DOCS, file);
  if (rel === "index.html") return "/";
  return `/${rel.replace(/\/index\.html$/, "/")}`;
}

function inferType(route) {
  if (route === "/") return PAGE_TYPES.home;
  if (route === "/authors/david-ahmann/") return PAGE_TYPES.profile;
  if (
    route === "/openclaw-2026/" ||
    route === "/ai-tool-sprawl-v2-2026/" ||
    route === "/ai-tool-sprawl-q1-2026/"
  ) {
    return PAGE_TYPES.report;
  }
  if (COLLECTION_ROUTES.has(route)) return PAGE_TYPES.collection;
  if (route.startsWith("/blog/")) return PAGE_TYPES.article;
  return PAGE_TYPES.collection;
}

function gitDate(file, mode) {
  const today = new Date().toISOString().slice(0, 10);
  try {
    const status = execFileSync("git", ["status", "--porcelain", "--", file], {
      cwd: ROOT,
      encoding: "utf8",
    }).trim();
    if (mode === "modified" && status) return today;

    if (mode === "created") {
      const out = execFileSync(
        "git",
        ["log", "--diff-filter=A", "--follow", "--format=%cs", "--", file],
        { cwd: ROOT, encoding: "utf8" }
      ).trim();
      if (out) {
        const lines = out.split("\n").filter(Boolean);
        return lines[lines.length - 1];
      }
    }
    const out = execFileSync("git", ["log", "-1", "--format=%cs", "--", file], {
      cwd: ROOT,
      encoding: "utf8",
    }).trim();
    if (out) return out;
  } catch {
    // fall through to today
  }
  return today;
}

function match(text, re, label, file) {
  const found = text.match(re);
  if (!found) {
    throw new Error(`Missing ${label} in ${file}`);
  }
  return found[1].trim();
}

function parseBreadcrumbs(html) {
  const matchBlock = html.match(/<p class="breadcrumbs">([\s\S]*?)<\/p>/);
  if (!matchBlock) return [];
  const items = [];
  const re = /<a href="([^"]+)">([^<]+)<\/a>|<span(?: class="[^"]*")?>([^<]+)<\/span>/g;
  let m;
  while ((m = re.exec(matchBlock[1]))) {
    if (m[1] && m[2]) {
      items.push({ name: m[2].trim(), url: m[1].trim() });
      continue;
    }
    if (m[3]) {
      const text = m[3].trim();
      if (!text || text === "/") continue;
      items.push({ name: text });
    }
  }
  return items;
}

function canonicalFor(route) {
  return route === "/" ? BASE_URL : `${BASE_URL}${route}`;
}

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function organizationObject() {
  return {
    "@type": "Organization",
    name: ORG_NAME,
    url: BASE_URL,
    logo: {
      "@type": "ImageObject",
      url: LOGO_IMAGE,
    },
    sameAs: ["https://github.com/Clyra-AI/safety"],
  };
}

function authorObject() {
  return {
    "@type": "Person",
    name: "David Ahmann",
    url: AUTHOR_PROFILE,
    image: AUTHOR_IMAGE,
    sameAs: ["https://www.linkedin.com/in/dahmann/"],
    jobTitle: "Head of Cloud & AI Platforms",
    worksFor: {
      "@type": "Organization",
      name: "CDW",
    },
  };
}

function breadcrumbObject(url, crumbs) {
  return {
    "@type": "BreadcrumbList",
    "@id": `${url}#breadcrumb`,
    itemListElement: crumbs.map((item, index) => {
      const data = {
        "@type": "ListItem",
        position: index + 1,
        name: item.name,
      };
      if (item.url) {
        data.item = item.url.startsWith("http")
          ? item.url
          : item.url === "/"
            ? BASE_URL
            : `${BASE_URL}${item.url}`;
      }
      return data;
    }),
  };
}

function webpageObject(type, url, title, description) {
  const pageType =
    type === PAGE_TYPES.collection
      ? "CollectionPage"
      : type === PAGE_TYPES.profile
        ? "ProfilePage"
        : "WebPage";
  return {
    "@type": pageType,
    "@id": `${url}#webpage`,
    url,
    name: title,
    description,
    inLanguage: "en",
    isPartOf: {
      "@id": `${BASE_URL}#website`,
    },
  };
}

function articleObject(type, url, headline, description, published, modified) {
  const articleType = type === PAGE_TYPES.report ? "Article" : "BlogPosting";
  return {
    "@type": articleType,
    headline,
    description,
    mainEntityOfPage: url,
    url,
    image: GENERIC_IMAGE,
    datePublished: published,
    dateModified: modified,
    inLanguage: "en",
    author: type === PAGE_TYPES.report ? organizationObject() : authorObject(),
    publisher: organizationObject(),
  };
}

function profileGraph(url, title, description) {
  return {
    "@context": "https://schema.org",
    "@graph": [
      webpageObject(PAGE_TYPES.profile, url, title, description),
      {
        "@type": "ProfilePage",
        mainEntity: {
          ...authorObject(),
          description,
          alumniOf: [
            { "@type": "Organization", name: "Rackspace Technology" },
            { "@type": "Organization", name: "OpsGuru" },
          ],
        },
      },
    ],
  };
}

function homeGraph(url, title, description) {
  return {
    "@context": "https://schema.org",
    "@graph": [
      organizationObject(),
      {
        "@type": "WebSite",
        "@id": `${BASE_URL}#website`,
        url: BASE_URL,
        name: SITE_NAME,
        description,
        publisher: organizationObject(),
        inLanguage: "en",
      },
      webpageObject(PAGE_TYPES.home, url, title, description),
    ],
  };
}

function buildGraph(meta) {
  const {
    type,
    url,
    title,
    headline,
    description,
    breadcrumbs,
    published,
    modified,
  } = meta;
  if (type === PAGE_TYPES.home) return homeGraph(url, title, description);
  if (type === PAGE_TYPES.profile) return profileGraph(url, title, description);

  const graph = [webpageObject(type, url, title, description)];
  if (breadcrumbs.length) graph.push(breadcrumbObject(url, breadcrumbs));
  if (type === PAGE_TYPES.article || type === PAGE_TYPES.report) {
    graph.push(articleObject(type, url, headline, description, published, modified));
  }
  return { "@context": "https://schema.org", "@graph": graph };
}

function buildMetaBlock(meta) {
  const { type, url, title, description, published, modified } = meta;
  const ogType =
    type === PAGE_TYPES.article || type === PAGE_TYPES.report
      ? "article"
      : type === PAGE_TYPES.profile
        ? "profile"
        : "website";
  const image = type === PAGE_TYPES.profile ? AUTHOR_IMAGE : GENERIC_IMAGE;
  const imageWidth = type === PAGE_TYPES.profile ? "160" : "1600";
  const imageHeight = type === PAGE_TYPES.profile ? "160" : "900";
  const lines = [
    '    <!-- SEO_META_START -->',
    `    <link rel="canonical" href="${url}" />`,
    '    <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1" />',
    `    <meta property="og:site_name" content="${escapeHtml(SITE_NAME)}" />`,
    `    <meta property="og:type" content="${ogType}" />`,
    `    <meta property="og:title" content="${escapeHtml(title)}" />`,
    `    <meta property="og:description" content="${escapeHtml(description)}" />`,
    `    <meta property="og:url" content="${url}" />`,
    `    <meta property="og:image" content="${image}" />`,
    `    <meta property="og:image:alt" content="${escapeHtml(title)}" />`,
    `    <meta property="og:image:width" content="${imageWidth}" />`,
    `    <meta property="og:image:height" content="${imageHeight}" />`,
    '    <meta name="twitter:card" content="summary_large_image" />',
    `    <meta name="twitter:title" content="${escapeHtml(title)}" />`,
    `    <meta name="twitter:description" content="${escapeHtml(description)}" />`,
    `    <meta name="twitter:image" content="${image}" />`,
  ];
  if (type === PAGE_TYPES.article) {
    lines.push('    <meta name="author" content="David Ahmann" />');
    lines.push(`    <link rel="author" href="${AUTHOR_PROFILE}" />`);
  }
  if (type === PAGE_TYPES.article || type === PAGE_TYPES.report) {
    lines.push(`    <meta property="article:published_time" content="${published}" />`);
    lines.push(`    <meta property="article:modified_time" content="${modified}" />`);
  }
  lines.push('    <!-- SEO_META_END -->');
  return lines.join("\n");
}

function buildSchemaBlock(meta) {
  const graph = buildGraph(meta);
  return [
    "    <!-- SEO_SCHEMA_START -->",
    '    <script type="application/ld+json">',
    JSON.stringify(graph, null, 2)
      .split("\n")
      .map((line) => `    ${line}`)
      .join("\n"),
    "    </script>",
    "    <!-- SEO_SCHEMA_END -->",
  ].join("\n");
}

function replaceOrInsert(html, block, startMarker, endMarker, anchorRe) {
  const range = new RegExp(
    `\\s*${startMarker}[\\s\\S]*?${endMarker}\\n?`,
    "m"
  );
  if (range.test(html)) return html.replace(range, `\n${block}\n`);
  return html.replace(anchorRe, `\n${block}\n$&`);
}

function main() {
  const files = walk(DOCS);
  for (const file of files) {
    const route = fileToRoute(file);
    const type = inferType(route);
    let html = fs.readFileSync(file, "utf8");
    const title = match(html, /<title>([^<]+)<\/title>/, "title", file);
    const description = match(
      html,
      /<meta\s+name="description"\s+content="([^"]+)"\s*\/>/,
      "description",
      file
    );
    const headlineMatch = html.match(/<h1>([^<]+)<\/h1>/);
    const headline = headlineMatch ? headlineMatch[1].trim() : title;
    const published = gitDate(file, "created");
    const modified = gitDate(file, "modified");
    const meta = {
      type,
      route,
      url: canonicalFor(route),
      title,
      headline,
      description,
      breadcrumbs: parseBreadcrumbs(html),
      published,
      modified,
    };

    html = replaceOrInsert(
      html,
      buildMetaBlock(meta),
      "<!-- SEO_META_START -->",
      "<!-- SEO_META_END -->",
      /\s*<link rel="stylesheet" href="\/assets\/site\.css" \/>/
    );
    html = replaceOrInsert(
      html,
      buildSchemaBlock(meta),
      "<!-- SEO_SCHEMA_START -->",
      "<!-- SEO_SCHEMA_END -->",
      /\s*<\/head>/
    );
    fs.writeFileSync(file, html);
  }
}

main();
