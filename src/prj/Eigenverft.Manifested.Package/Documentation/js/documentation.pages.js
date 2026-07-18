(function (global) {
  'use strict';

  global.DocumentationSite = {
    brand: 'Eigenverft.Manifested.Package',
    brandIcon: 'bi-box-seam',
    pages: [
      { path: 'index.html', label: 'Overview', title: 'Eigenverft.Manifested.Package documentation', icon: 'bi-house-door' },
      { path: 'OfflineBootstrap.html', label: 'Offline setup', title: 'Offline Windows setup — Eigenverft.Manifested.Package', icon: 'bi-device-hdd' },
      { path: 'DocTemplate.html', label: 'Document template', title: 'Documentation page template — Eigenverft.Manifested.Package', icon: 'bi-file-earmark-code' }
    ],
    onlineLinks: [
      { href: 'https://github.com/eigenverft/Eigenverft.Manifested.Package', label: 'Code', icon: 'bi-github' },
      { href: 'https://github.com/eigenverft/Eigenverft.Manifested.Package/issues', label: 'Issues', icon: 'bi-bug' },
      { href: 'https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package', label: 'Gallery', icon: 'bi-cloud-arrow-down' }
    ]
  };
}(window));
