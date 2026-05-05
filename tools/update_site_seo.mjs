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
const ORG_ID = `${BASE_URL}#organization`;
const WEBSITE_ID = `${BASE_URL}#website`;
const AUTHOR_ID = `${AUTHOR_PROFILE}#person`;

const PAGE_TYPES = {
  home: "home",
  report: "report",
  reference: "reference",
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

const REFERENCE_ROUTES = new Set([
  "/agent-action-bom/",
  "/secure-ai-coding-agents-ci-cd/",
  "/blog/ai-agent-governance/",
  "/blog/glossary/",
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
  if (REFERENCE_ROUTES.has(route)) return PAGE_TYPES.reference;
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
    "@id": ORG_ID,
    name: ORG_NAME,
    url: BASE_URL,
    description:
      "Independent, reproducible research and operating notes on AI Software Delivery Control, AI agent governance, execution boundaries, proof quality, and safe adoption.",
    logo: {
      "@type": "ImageObject",
      url: LOGO_IMAGE,
    },
    email: "david@caisi.dev",
    contactPoint: [
      {
        "@type": "ContactPoint",
        contactType: "research inquiries",
        email: "david@caisi.dev",
        url: BASE_URL,
        availableLanguage: ["en"],
      },
    ],
    knowsAbout: [
      "AI agent governance",
      "AI Software Delivery Control",
      "Agent Action BOM",
      "AI coding agent security",
      "CI/CD agent security",
      "AI agent control",
      "execution boundaries",
      "tool-boundary enforcement",
      "approval mediation",
      "evidence quality",
      "safe AI adoption",
      "reproducible AI governance research",
    ],
  };
}

function authorObject() {
  return {
    "@type": "Person",
    "@id": AUTHOR_ID,
    name: "David Ahmann",
    url: AUTHOR_PROFILE,
    image: AUTHOR_IMAGE,
    description:
      "David Ahmann writes at CAISI about AI agent governance, execution boundaries, evidence quality, and safe adoption for AppSec, platform, and engineering leaders.",
    sameAs: ["https://www.linkedin.com/in/dahmann/"],
    jobTitle: "Head of Cloud & AI Platforms",
    worksFor: {
      "@type": "Organization",
      name: "CDW",
    },
  };
}

function websiteObject(description) {
  return {
    "@type": "WebSite",
    "@id": WEBSITE_ID,
    url: BASE_URL,
    name: SITE_NAME,
    description,
    publisher: {
      "@id": ORG_ID,
    },
    inLanguage: "en",
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
    about: {
      "@id": ORG_ID,
    },
    isPartOf: {
      "@id": WEBSITE_ID,
    },
  };
}

function articleObject(type, url, headline, description, published, modified) {
  const articleType =
    type === PAGE_TYPES.report
      ? "Article"
      : type === PAGE_TYPES.reference
        ? "TechArticle"
        : "BlogPosting";
  return {
    "@type": articleType,
    "@id": `${url}#article`,
    headline,
    description,
    mainEntityOfPage: url,
    url,
    image: GENERIC_IMAGE,
    datePublished: published,
    dateModified: modified,
    inLanguage: "en",
    about: {
      "@id": ORG_ID,
    },
    author:
      type === PAGE_TYPES.report
        ? {
            "@id": ORG_ID,
          }
        : {
            "@id": AUTHOR_ID,
          },
    publisher: {
      "@id": ORG_ID,
    },
    keywords: [
      "AI Software Delivery Control",
      "Agent Action BOM",
      "AI agent governance",
      "AI coding agent security",
      "CI/CD agent security",
    ],
  };
}

function profileGraph(url, title, description) {
  return {
    "@context": "https://schema.org",
    "@graph": [
      organizationObject(),
      websiteObject(description),
      webpageObject(PAGE_TYPES.profile, url, title, description),
      {
        "@type": "ProfilePage",
        "@id": `${url}#profile`,
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
      websiteObject(description),
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

  const graph = [
    organizationObject(),
    websiteObject(description),
    webpageObject(type, url, title, description),
  ];
  if (type === PAGE_TYPES.article || type === PAGE_TYPES.reference) {
    graph.push(authorObject());
  }
  if (breadcrumbs.length) graph.push(breadcrumbObject(url, breadcrumbs));
  if (
    type === PAGE_TYPES.article ||
    type === PAGE_TYPES.report ||
    type === PAGE_TYPES.reference
  ) {
    graph.push(articleObject(type, url, headline, description, published, modified));
  }
  return { "@context": "https://schema.org", "@graph": graph };
}

function buildMetaBlock(meta) {
  const { type, url, title, description, published, modified } = meta;
  const ogType =
    type === PAGE_TYPES.article ||
    type === PAGE_TYPES.report ||
    type === PAGE_TYPES.reference
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
    '    <link rel="alternate" type="text/plain" href="/llms.txt" title="CAISI llms.txt" />',
    '    <link rel="alternate" type="text/plain" href="/llms-full.txt" title="CAISI llms-full.txt" />',
  ];
  if (type === PAGE_TYPES.article || type === PAGE_TYPES.reference) {
    lines.push('    <meta name="author" content="David Ahmann" />');
    lines.push(`    <link rel="author" href="${AUTHOR_PROFILE}" />`);
  }
  if (
    type === PAGE_TYPES.article ||
    type === PAGE_TYPES.report ||
    type === PAGE_TYPES.reference
  ) {
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

function sitemapPriority(route, type) {
  if (route === "/") return "1.0";
  if (type === PAGE_TYPES.reference || type === PAGE_TYPES.report) return "0.9";
  if (type === PAGE_TYPES.collection || route === "/roles/" || route === "/research/") {
    return "0.8";
  }
  return "0.6";
}

function sitemapChangefreq(type) {
  if (type === PAGE_TYPES.home || type === PAGE_TYPES.collection) return "weekly";
  if (type === PAGE_TYPES.reference) return "monthly";
  return "yearly";
}

function buildSitemap(entries) {
  const order = [
    "/",
    "/roles/",
    "/research/",
    "/agent-action-bom/",
    "/secure-ai-coding-agents-ci-cd/",
    "/openclaw-2026/",
    "/ai-tool-sprawl-v2-2026/",
    "/ai-tool-sprawl-q1-2026/",
    "/blog/",
  ];
  const byRoute = new Map(entries.map((entry) => [entry.route, entry]));
  const sorted = [
    ...order.map((route) => byRoute.get(route)).filter(Boolean),
    ...entries
      .filter((entry) => !order.includes(entry.route))
      .sort((a, b) => a.route.localeCompare(b.route)),
  ];
  const urls = sorted
    .map((entry) => {
      return [
        "  <url>",
        `    <loc>${entry.url}</loc>`,
        `    <lastmod>${entry.modified}</lastmod>`,
        `    <changefreq>${sitemapChangefreq(entry.type)}</changefreq>`,
        `    <priority>${sitemapPriority(entry.route, entry.type)}</priority>`,
        "  </url>",
      ].join("\n");
    })
    .join("\n");
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    urls,
    "</urlset>",
    "",
  ].join("\n");
}

function main() {
  const files = walk(DOCS);
  const sitemapEntries = [];
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
    sitemapEntries.push({
      route,
      url: meta.url,
      type,
      modified,
    });

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
  fs.writeFileSync(path.join(DOCS, "sitemap.xml"), buildSitemap(sitemapEntries));
}

main();
