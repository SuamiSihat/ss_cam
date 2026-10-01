/**
 * Markdown & Obsidian Callout Parser Service for Svelte 5
 */
import { marked } from 'marked';
import DOMPurify from 'dompurify';

export interface MarkdownToken {
  type: string;
  raw: string;
  text?: string;
  lang?: string;
  tokens?: any[];
  [key: string]: any;
}

export class MarkdownService {
  /**
   * Transforms Obsidian / GFM callout blockquotes into styled alert containers.
   * e.g. > [!NOTE] -> <div class="callout callout-note">...</div>
   */
  static transformCallouts(markdown: string): string {
    if (!markdown) return '';

    // Match > [!TYPE] Title on blockquote line
    const calloutRegex = /^>\s*\[!(NOTE|WARNING|IMPORTANT|CAUTION|DANGER|TIP|SUCCESS)\]\s*(.*)$/gim;

    const lines = markdown.split('\n');
    let inCallout = false;
    let calloutType = '';
    let calloutTitle = '';
    let outputLines: string[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const match = line.match(/^>\s*\[!(NOTE|WARNING|IMPORTANT|CAUTION|DANGER|TIP|SUCCESS)\]\s*(.*)$/i);

      if (match) {
        if (inCallout) {
          outputLines.push('</div>');
        }
        inCallout = true;
        calloutType = match[1].toLowerCase();
        calloutTitle = match[2].trim() || match[1].toUpperCase();
        outputLines.push(`<div class="callout callout-${calloutType}"><div class="callout-title">${calloutTitle}</div>`);
        continue;
      }

      if (inCallout) {
        if (line.startsWith('>')) {
          outputLines.push(line.replace(/^>\s?/, ''));
        } else if (line.trim() === '') {
          outputLines.push('');
        } else {
          inCallout = false;
          outputLines.push('</div>');
          outputLines.push(line);
        }
      } else {
        outputLines.push(line);
      }
    }

    if (inCallout) {
      outputLines.push('</div>');
    }

    return outputLines.join('\n');
  }

  /**
   * Transforms Obsidian-style wiki links [[...]] or ![[...]] and relative images
   * into rendered image tags or attachment pills.
   */
  static transformWikilinksAndAttachments(markdown: string, projectId?: string): string {
    if (!markdown) return '';

    // 1. Transform standard markdown relative images: ![alt](\path\to\image.jpg) or ![alt](path/to/image.jpg)
    const stdImgRegex = /!\[(.*?)\]\((.*?)\)/g;
    let result = markdown.replace(stdImgRegex, (match, alt, rawUrl) => {
      const trimmed = (rawUrl || '').trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:') || trimmed.startsWith('/api/')) {
        return match;
      }
      const cleanPath = trimmed.replace(/\0/g, '').replace(/\\+/g, '/').replace(/^\/+/, '');
      if (projectId) {
        const assetUrl = `/api/projects/${encodeURIComponent(projectId)}/asset?path=${encodeURIComponent(cleanPath)}`;
        return `![${alt}](${assetUrl})`;
      }
      return match;
    });

    // 2. Transform Obsidian wikilinks: [[path\to\file.ext]] or ![[path\to\file.ext|alias_or_width]]
    // Matches !?[[target|optional_alias]]
    const wikilinkRegex = /!?\[\[\s*([^\]|\n]+?)(?:\|([^\]\n]*))?\s*\]\]/g;
    result = result.replace(wikilinkRegex, (_match, rawTarget, aliasOrSize) => {
      const cleanTarget = (rawTarget || '').trim().replace(/\0/g, '').replace(/\\+/g, '/').replace(/^\/+/, '');
      if (!cleanTarget) return '';

      const filename = cleanTarget.split('/').pop() || cleanTarget;
      const isImage = /\.(jpe?g|png|gif|webp|svg|bmp|avif)$/i.test(cleanTarget);
      
      const assetUrl = projectId
        ? `/api/projects/${encodeURIComponent(projectId)}/asset?path=${encodeURIComponent(cleanTarget)}`
        : cleanTarget;

      if (isImage) {
        const trimmedAlias = (aliasOrSize || '').trim();
        const isWidthOnly = /^\d+(?:px)?$/i.test(trimmedAlias);
        const width = isWidthOnly ? trimmedAlias.replace(/px/i, '') : null;
        const widthStyle = width ? `style="max-width: ${width}px;"` : '';
        const altText = (!isWidthOnly && trimmedAlias) ? trimmedAlias : filename;

        return `\n\n<div class="markdown-image-block"><a href="${assetUrl}" target="_blank" rel="noopener noreferrer" class="markdown-image-link" title="Open ${altText} in new tab"><img src="${assetUrl}" alt="${altText}" class="markdown-attached-image" loading="lazy" ${widthStyle}/></a><div class="markdown-image-caption">${filename}</div></div>\n\n`;
      } else {
        const linkText = (aliasOrSize || '').trim() || filename;
        return ` <a href="${assetUrl}" target="_blank" rel="noopener noreferrer" class="markdown-attachment-badge" download="${filename}"><span class="attachment-icon">📎</span> <span class="attachment-name">${linkText}</span></a> `;
      }
    });

    return result;
  }

  /**
   * Parses Markdown string to sanitized HTML.
   */
  static renderToHtml(markdown: string, projectId?: string): string {
    if (!markdown || typeof markdown !== 'string') return '';
    
    const withAttachments = this.transformWikilinksAndAttachments(markdown, projectId);
    const withCallouts = this.transformCallouts(withAttachments);
    const rawHtml = marked.parse(withCallouts, { gfm: true, breaks: true }) as string;
    
    return DOMPurify.sanitize(rawHtml, {
      ADD_TAGS: ['div', 'span', 'svg', 'path', 'code', 'pre', 'input', 'img', 'figure', 'figcaption', 'a'],
      ADD_ATTR: ['class', 'id', 'style', 'type', 'checked', 'disabled', 'viewBox', 'd', 'fill', 'src', 'alt', 'loading', 'href', 'target', 'rel', 'download', 'title']
    });
  }

  /**
   * Tokenizes markdown into blocks (used by Svelte to separate standard markdown from Mermaid code blocks).
   */
  static tokenize(markdown: string): MarkdownToken[] {
    if (!markdown) return [];
    return marked.lexer(markdown, { gfm: true }) as MarkdownToken[];
  }
}
