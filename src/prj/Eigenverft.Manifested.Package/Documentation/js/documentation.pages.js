(function (global) {
  'use strict';

  global.DocumentationSite = {
    brand: 'Eigenverft.Manifested.Package',
    brandIcon: 'bi-box-seam',
    pages: [
      { path: 'index.html', label: 'Overview', title: 'Eigenverft.Manifested.Package documentation', icon: 'bi-house-door' },
      { path: 'PackageDepots.html', label: 'Package depots', title: 'Package depots — Eigenverft.Manifested.Package', icon: 'bi-database' },
      { path: 'PackageDepotCommands.html', label: 'Depot commands', title: 'Package depot commands — Eigenverft.Manifested.Package', icon: 'bi-terminal' },
      { path: 'PackageDepotMaterialize.html', label: 'Fill depots', title: 'Fill package depots — Eigenverft.Manifested.Package', icon: 'bi-arrow-repeat' },
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
