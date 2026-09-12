#!/usr/bin/env python3
"""Original geometric player glyphs using the project's antialiased PNG writer."""
from make_theme_assets import icon, rounded

icon('player-play', [[(24,16),(48,32),(24,48),(24,16)]])
icon('player-pause', [[(24,17),(24,47)],[(40,17),(40,47)]])
icon('player-audio', [[(13,25),(23,25),(34,15),(34,49),(23,39),(13,39),(13,25)],[(43,23),(48,28),(48,36),(43,41)],[(49,15),(56,24),(56,40),(49,49)]])
icon('player-captions', [[(8,16),(56,16),(56,48),(8,48),(8,16)],[(28,25),(20,25),(17,29),(17,36),(20,39),(28,39)],[(48,25),(40,25),(37,29),(37,36),(40,39),(48,39)]])
icon('player-live', [[(36,10),(19,35),(31,35),(27,54),(46,27),(34,27),(36,10)]])
rounded('player-circle.png',64,64,32)
