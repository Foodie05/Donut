# Changelog

## 1.1.0

### Reader and summary experience
- Added dark mode support with system-follow, light, and dark appearance options.
- Reading time now counts only while a PDF is open and the app is active in the foreground.
- Added smooth summary prefetching so the next page summary can be prepared in advance when the AI panel is open.
- Added power saving mode so closing the AI panel pauses new summary countdowns and new summary tasks.

### Summary profiles
- Added summary profiles so you can choose different prompts for page summaries.
- Included a built-in `默认摘要` profile as a reference prompt that can be viewed and copied.
- Added support for creating, selecting, editing, and deleting custom summary profiles.
- Summary results are now isolated by profile, so switching profiles gives each page its own independent summary and chat context.

### Settings and localization
- Added a `阅读器` section in Settings to group reading and summary options more clearly.
- Added a `摘要配置文件` entry in Settings for managing summary prompts.
- Localized the reading direction setting and expanded Chinese support for the new options.
