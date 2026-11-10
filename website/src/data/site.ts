const repo = 'https://github.com/Hitjack007/CalWidget';

export const app = {
  name: 'CalWidget',
  url: 'https://gcalwidget.marksstuff.com',
  tagline: 'Your Google Calendar, as a real macOS widget.',
  repo,
  issues: `${repo}/issues`,
  newIssue: `${repo}/issues/new`,
  download: `${repo}/releases/latest`,
  brew: 'brew install --cask hitjack007/calwidget/calwidget',
  unquarantine: 'xattr -dr com.apple.quarantine /Applications/CalWidget.app',
  requirements: 'macOS 26 Tahoe or later',
  email: 'mark@gcalwidget.marksstuff.com',
  supportEmail: 'support@gcalwidget.marksstuff.com',
  legalEmail: 'legal@gcalwidget.marksstuff.com',
  discord: 'hitjack007',
  author: { name: 'Mark Greene', url: 'https://marksstuff.com' },
};

export const nav = [
  { href: '/support', label: 'Support' },
  { href: '/privacy', label: 'Privacy' },
];
