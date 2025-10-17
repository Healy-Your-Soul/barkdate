# Mobile-First Responsive + Container System Plan

(Consolidated plan applied in this branch. See file contents of /barkdate-mvp-refinement.plan.md for original.)

- Replace ad-hoc UI with AppCard/AppImageCard/AppButton/AppSectionHeader/AppBottomSheet/AppFAB
- Mobile tokens: padding 12/16; horizontal card width 150/170/200; heights 92–100 mini, 140–160 content; avatar 16–18; icon 16–18; title 14–16; body 12–14
- Feed Friends & Barks: fixed height, fixed item width, tighter padding, Flexible buttons, ellipsis
- Quick Actions cap height; Events/Playdates sizing; Map FAB restored; bottom sheet fix
- Dev: use --web-renderer=html; kill port 8080 before launch; gate FCM topics on web
- Perf: cached_network_image; trim debug logs; add null guards in services

