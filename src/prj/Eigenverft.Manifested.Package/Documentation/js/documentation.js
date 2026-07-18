(function () {
  'use strict';

  var clipboardInstance = null;

  function createElement(tagName, className, text) {
    var element = document.createElement(tagName);
    if (className) {
      element.className = className;
    }
    if (text) {
      element.textContent = text;
    }
    return element;
  }

  function getDocumentationConfig() {
    var config = window.DocumentationSite || {};
    return {
      brand: config.brand || 'Documentation',
      brandIcon: config.brandIcon || 'bi-box-seam',
      pages: Array.isArray(config.pages) ? config.pages : [],
      onlineLinks: Array.isArray(config.onlineLinks) ? config.onlineLinks : []
    };
  }

  function getCurrentPageName() {
    var path = decodeURIComponent(window.location.pathname || '').replace(/\\/g, '/');
    var fileName = path.substring(path.lastIndexOf('/') + 1);
    return fileName || 'index.html';
  }

  function getCurrentPage(config) {
    var currentPageName = getCurrentPageName().toLowerCase();
    var currentPage = null;
    Array.prototype.some.call(config.pages, function (page) {
      if (String(page.path).toLowerCase() !== currentPageName) {
        return false;
      }
      currentPage = page;
      return true;
    });
    return currentPage;
  }

  function applyDocumentTitle(config) {
    var currentPage = getCurrentPage(config);
    document.title = currentPage && currentPage.title ? currentPage.title : config.brand + ' documentation';
  }

  function appendIconLabel(element, iconClass, label) {
    var icon = createElement('i', 'bi ' + iconClass);
    var text = createElement('span', null, label);
    icon.setAttribute('aria-hidden', 'true');
    element.appendChild(icon);
    element.appendChild(text);
  }

  function createDocumentationNavigation(config) {
    var navigation = createElement('nav', 'navbar navbar-expand-md sticky-top bg-body-tertiary border-bottom documentation-navbar');
    var container = createElement('div', 'container-fluid page-width');
    var brand = createElement('a', 'navbar-brand');
    var toggle = createElement('button', 'navbar-toggler');
    var toggleIcon = createElement('span', 'navbar-toggler-icon');
    var collapse = createElement('div', 'collapse navbar-collapse');
    var pageList = createElement('ul', 'navbar-nav ms-auto');
    var documentationItem = createElement('li', 'nav-item dropdown');
    var documentationToggle = createElement('a', 'nav-link dropdown-toggle');
    var documentationMenu = createElement('ul', 'dropdown-menu dropdown-menu-end');
    var currentPage = getCurrentPageName().toLowerCase();

    navigation.setAttribute('aria-label', 'Documentation pages');
    brand.href = './index.html';
    appendIconLabel(brand, config.brandIcon, config.brand);
    toggle.type = 'button';
    toggle.setAttribute('data-bs-toggle', 'collapse');
    toggle.setAttribute('data-bs-target', '#documentation-navigation');
    toggle.setAttribute('aria-controls', 'documentation-navigation');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Toggle documentation navigation');
    collapse.id = 'documentation-navigation';
    documentationToggle.href = '#';
    documentationToggle.setAttribute('role', 'button');
    documentationToggle.setAttribute('data-bs-toggle', 'dropdown');
    documentationToggle.setAttribute('aria-expanded', 'false');
    appendIconLabel(documentationToggle, 'bi-journal-text', 'Documentation');

    Array.prototype.forEach.call(config.pages, function (page) {
      var item = createElement('li');
      var link = createElement('a', 'dropdown-item');
      link.href = './' + page.path;
      appendIconLabel(link, page.icon || 'bi-file-earmark-text', page.label || page.path);
      if (String(page.path).toLowerCase() === currentPage) {
        link.classList.add('active');
        link.setAttribute('aria-current', 'page');
      }
      item.appendChild(link);
      documentationMenu.appendChild(item);
    });

    documentationItem.appendChild(documentationToggle);
    documentationItem.appendChild(documentationMenu);
    pageList.appendChild(documentationItem);

    if (config.onlineLinks.length) {
      var onlineItem = createElement('li', 'nav-item dropdown');
      var onlineToggle = createElement('a', 'nav-link dropdown-toggle');
      var onlineMenu = createElement('ul', 'dropdown-menu dropdown-menu-end');
      onlineToggle.href = '#';
      onlineToggle.setAttribute('role', 'button');
      onlineToggle.setAttribute('data-bs-toggle', 'dropdown');
      onlineToggle.setAttribute('aria-expanded', 'false');
      appendIconLabel(onlineToggle, 'bi-cloud', 'Online');

      Array.prototype.forEach.call(config.onlineLinks, function (onlineLink) {
        var item = createElement('li');
        var link = createElement('a', 'dropdown-item');
        link.href = onlineLink.href;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        appendIconLabel(link, onlineLink.icon || 'bi-box-arrow-up-right', onlineLink.label || onlineLink.href);
        item.appendChild(link);
        onlineMenu.appendChild(item);
      });

      onlineItem.appendChild(onlineToggle);
      onlineItem.appendChild(onlineMenu);
      pageList.appendChild(onlineItem);
    }

    toggle.appendChild(toggleIcon);
    collapse.appendChild(pageList);
    container.appendChild(brand);
    container.appendChild(toggle);
    container.appendChild(collapse);
    navigation.appendChild(container);
    return navigation;
  }

  function createDocumentationShell(source, config) {
    var target = createElement('main', 'page-width documentation-content');
    var loading = createElement('p', 'loading-message', 'Loading packaged documentation…');

    target.id = 'documentation-content';
    target.setAttribute('aria-live', 'polite');
    target.appendChild(loading);

    document.body.insertBefore(createDocumentationNavigation(config), source);
    document.body.insertBefore(target, source);
    return target;
  }

  function showRenderError(target, message) {
    target.classList.add('warning-panel');
    target.textContent = message;
  }

  function prefersDarkColorScheme() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  function configureBootstrapTheme() {
    var colorScheme = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
    var applyTheme = function () {
      document.documentElement.setAttribute('data-bs-theme', prefersDarkColorScheme() ? 'dark' : 'light');
    };

    applyTheme();
    if (colorScheme && typeof colorScheme.addEventListener === 'function') {
      colorScheme.addEventListener('change', applyTheme);
    } else if (colorScheme && typeof colorScheme.addListener === 'function') {
      colorScheme.addListener(applyTheme);
    }
  }

  function applyBootstrapContentStyles(target) {
    Array.prototype.forEach.call(target.querySelectorAll('table'), function (table) {
      table.classList.add('table', 'table-striped', 'table-hover', 'align-middle');
    });

    Array.prototype.forEach.call(target.querySelectorAll('blockquote'), function (quote) {
      quote.classList.add('alert', 'alert-secondary');
    });
  }

  function restoreEscapedHtmlExamples(target) {
    var escapedClosingTag = '<\\/script>';
    var closingTag = '</scr' + 'ipt>';
    Array.prototype.forEach.call(target.querySelectorAll('pre > code.language-html'), function (code) {
      if (code.textContent.indexOf(escapedClosingTag) >= 0) {
        code.textContent = code.textContent.split(escapedClosingTag).join(closingTag);
      }
    });
  }

  function addHeadingAnchors(target) {
    var usedIds = Object.create(null);
    Array.prototype.forEach.call(target.querySelectorAll('h2, h3'), function (heading) {
      var baseId = heading.textContent
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '') || 'section';
      var id = baseId;
      var suffix = 2;
      while (usedIds[id] || document.getElementById(id)) {
        id = baseId + '-' + suffix;
        suffix += 1;
      }
      usedIds[id] = true;
      heading.id = id;
    });
  }

  function setCopyButtonState(button, label, state) {
    button.textContent = label;
    button.setAttribute('data-copy-state', state);
    window.setTimeout(function () {
      if (button.getAttribute('data-copy-state') === state) {
        button.textContent = 'Copy';
        button.setAttribute('data-copy-state', 'ready');
      }
    }, 1400);
  }

  function addCodeCopyButtons(target) {
    if (!window.ClipboardJS) {
      if (window.console && typeof window.console.warn === 'function') {
        window.console.warn('The packaged ClipboardJS library could not be loaded.');
      }
      return;
    }

    Array.prototype.forEach.call(target.querySelectorAll('pre > code'), function (code) {
      var pre = code.parentNode;
      var wrapper = document.createElement('div');
      var button = document.createElement('button');

      wrapper.className = 'code-block';
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);

      button.type = 'button';
      button.className = 'copy-button';
      button.textContent = 'Copy';
      button.setAttribute('aria-label', 'Copy code block');
      button.setAttribute('data-copy-state', 'ready');
      wrapper.appendChild(button);
    });

    if (clipboardInstance) {
      clipboardInstance.destroy();
    }
    clipboardInstance = new window.ClipboardJS(target.querySelectorAll('.copy-button'), {
      text: function (trigger) {
        var code = trigger.parentNode.querySelector('pre > code');
        return code ? code.textContent.replace(/\n$/, '') : '';
      }
    });
    clipboardInstance.on('success', function (event) {
      setCopyButtonState(event.trigger, 'Copied', 'copied');
      event.clearSelection();
    });
    clipboardInstance.on('error', function (event) {
      setCopyButtonState(event.trigger, 'Copy failed', 'failed');
    });
  }

  function renderMermaidDiagrams(target) {
    var codeBlocks = target.querySelectorAll('pre > code.language-mermaid');
    if (!codeBlocks.length) {
      return;
    }

    if (!window.mermaid || typeof window.mermaid.run !== 'function') {
      if (window.console && typeof window.console.warn === 'function') {
        window.console.warn('The packaged Mermaid renderer could not be loaded.');
      }
      return;
    }

    Array.prototype.forEach.call(codeBlocks, function (codeBlock) {
      var container = document.createElement('div');
      container.className = 'mermaid';
      container.textContent = codeBlock.textContent;
      codeBlock.parentNode.parentNode.replaceChild(container, codeBlock.parentNode);
    });

    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: prefersDarkColorScheme() ? 'dark' : 'default'
    });

    var renderResult = window.mermaid.run({
      nodes: target.querySelectorAll('.mermaid')
    });
    if (renderResult && typeof renderResult.catch === 'function') {
      renderResult.catch(function (error) {
        if (window.console && typeof window.console.error === 'function') {
          window.console.error(error);
        }
      });
    }
  }

  function renderDocumentation() {
    var source = document.getElementById('documentation-markdown');
    var config = getDocumentationConfig();

    if (!source) {
      return;
    }

    applyDocumentTitle(config);
    var target = document.getElementById('documentation-content') || createDocumentationShell(source, config);

    if (!window.marked || typeof window.marked.parse !== 'function') {
      showRenderError(target, 'The packaged Markdown renderer could not be loaded.');
      return;
    }

    try {
      target.innerHTML = window.marked.parse(source.textContent.trim(), {
        gfm: true
      });
      restoreEscapedHtmlExamples(target);
      addHeadingAnchors(target);
      applyBootstrapContentStyles(target);
      renderMermaidDiagrams(target);
      addCodeCopyButtons(target);
    } catch (error) {
      showRenderError(target, 'The packaged documentation could not be rendered.');
      if (window.console && typeof window.console.error === 'function') {
        window.console.error(error);
      }
    }
  }

  configureBootstrapTheme();

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', renderDocumentation);
  } else {
    renderDocumentation();
  }
}());
