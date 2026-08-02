#!/usr/bin/env python3
"""Generate a static HTML mockup of the SonicTune UI for preview.

This mirrors the structure of src/sonictune/ui/qml/main.qml and produces
a self-contained HTML file showing what the UI looks like.
"""
from pathlib import Path

OUTPUT = Path("/home/z/my-project/download/sonictune-ui-mockup.html")

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SonicTune — UI Mockup</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif;
    background: #1C1B1F;
    color: #E6E1E5;
    height: 100vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* Connection banner */
  .banner {
    background: transparent;
    color: transparent;
    height: 0;
    transition: height 0.2s;
  }

  /* Main layout */
  .app {
    flex: 1;
    display: flex;
    flex-direction: row;
  }

  /* Navigation rail */
  .nav-rail {
    width: 64px;
    background: #2B2930;
    padding: 16px 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
  }
  .logo {
    width: 48px; height: 48px;
    background: #6750A4;
    border-radius: 16px;
    display: flex; align-items: center; justify-content: center;
    font-size: 24px;
    margin-bottom: 8px;
  }
  .nav-btn {
    width: 56px; height: 56px;
    border-radius: 16px;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    cursor: pointer;
    color: #CAC4D0;
    font-size: 11px;
    transition: background 0.15s;
  }
  .nav-btn:hover { background: rgba(255,255,255,0.05); }
  .nav-btn.active { background: #49454F; color: #D0BCFF; }
  .nav-btn .icon { font-size: 20px; margin-bottom: 2px; }

  /* Main content area */
  .main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* Page content */
  .page {
    flex: 1;
    padding: 32px 48px;
    overflow-y: auto;
  }
  .page h1 {
    font-size: 28px;
    font-weight: 500;
    margin-bottom: 24px;
    color: #E6E1E5;
  }
  .page h2 {
    font-size: 22px;
    font-weight: 500;
    margin: 24px 0 12px 0;
    color: #E6E1E5;
  }

  /* Auth prompt (Home page state) */
  .auth-card {
    background: #2B2930;
    border-radius: 16px;
    padding: 40px;
    max-width: 400px;
    margin: 80px auto;
    text-align: center;
  }
  .auth-card .icon { font-size: 48px; margin-bottom: 16px; }
  .auth-card h2 { font-size: 24px; color: #E6E1E5; }
  .auth-card p {
    color: #CAC4D0;
    font-size: 14px;
    margin: 12px 0 24px 0;
    line-height: 1.5;
  }
  .auth-btn {
    background: #6750A4;
    color: white;
    border: none;
    padding: 10px 24px;
    border-radius: 20px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
  }

  /* Sample library content (what it would look like after auth) */
  .library-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 16px;
    margin-bottom: 32px;
  }
  .album-card {
    cursor: pointer;
  }
  .album-card .art {
    width: 100%;
    aspect-ratio: 1;
    background: linear-gradient(135deg, #6750A4, #9A82DB);
    border-radius: 12px;
    margin-bottom: 8px;
    display: flex; align-items: center; justify-content: center;
    font-size: 64px;
  }
  .album-card:nth-child(2n) .art { background: linear-gradient(135deg, #0061A4, #6750A4); }
  .album-card:nth-child(3n) .art { background: linear-gradient(135deg, #B3261E, #6750A4); }
  .album-card:nth-child(5n) .art { background: linear-gradient(135deg, #386A20, #6750A4); }
  .album-card .title {
    font-size: 16px; font-weight: 500;
    color: #E6E1E5;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .album-card .artist {
    font-size: 12px; color: #CAC4D0;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }

  /* Player bar */
  .player-bar {
    height: 80px;
    background: #2B2930;
    border-top: 1px solid #49454F;
    display: flex;
    align-items: center;
    padding: 0 16px;
    gap: 16px;
    flex-shrink: 0;
  }
  .pb-art {
    width: 56px; height: 56px;
    border-radius: 8px;
    background: linear-gradient(135deg, #6750A4, #9A82DB);
    display: flex; align-items: center; justify-content: center;
    font-size: 24px;
    flex-shrink: 0;
  }
  .pb-info {
    width: 240px;
    flex-shrink: 0;
  }
  .pb-info .title { font-size: 16px; font-weight: 500; }
  .pb-info .artist { font-size: 12px; color: #CAC4D0; }

  .pb-controls {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 16px;
  }
  .pb-btn {
    width: 36px; height: 36px;
    border-radius: 50%;
    background: transparent;
    border: none;
    color: #E6E1E5;
    cursor: pointer;
    font-size: 16px;
    display: flex; align-items: center; justify-content: center;
  }
  .pb-btn:hover { background: rgba(255,255,255,0.08); }
  .pb-btn.active { background: #49454F; color: #D0BCFF; }
  .pb-play {
    width: 48px; height: 48px;
    border-radius: 50%;
    background: #D0BCFF;
    color: #381E72;
    font-size: 22px;
  }

  .pb-seek {
    flex: 1;
    max-width: 400px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .pb-seek-bar {
    height: 4px;
    background: #49454F;
    border-radius: 2px;
    position: relative;
  }
  .pb-seek-fill {
    width: 35%;
    height: 100%;
    background: #D0BCFF;
    border-radius: 2px;
  }
  .pb-seek-times {
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: #CAC4D0;
  }

  .pb-volume {
    width: 140px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .pb-volume-bar {
    flex: 1;
    height: 3px;
    background: #49454F;
    border-radius: 1.5px;
    position: relative;
  }
  .pb-volume-fill {
    width: 80%;
    height: 100%;
    background: #CAC4D0;
    border-radius: 1.5px;
  }

  /* Section divider */
  .section-title {
    font-size: 22px;
    font-weight: 500;
    margin-bottom: 16px;
  }
</style>
</head>
<body>

<div class="banner"></div>

<div class="app">
  <!-- Navigation rail -->
  <div class="nav-rail">
    <div class="logo">♪</div>
    <div class="nav-btn active"><span class="icon">🏠</span>Home</div>
    <div class="nav-btn"><span class="icon">🔍</span>Search</div>
    <div class="nav-btn"><span class="icon">📚</span>Library</div>
    <div class="nav-btn"><span class="icon">📊</span>Stats</div>
    <div class="nav-btn"><span class="icon">🎵</span>Now Playing</div>
    <div class="nav-btn"><span class="icon">⚙️</span>Settings</div>
  </div>

  <div class="main">
    <!-- Page content -->
    <div class="page">
      <h1>Home</h1>

      <div class="section-title">Quick Picks</div>
      <div class="library-grid">
        <div class="album-card">
          <div class="art">🎵</div>
          <div class="title">A Night at the Opera</div>
          <div class="artist">Queen</div>
        </div>
        <div class="album-card">
          <div class="art">🎹</div>
          <div class="title">The Dark Side of the Moon</div>
          <div class="artist">Pink Floyd</div>
        </div>
        <div class="album-card">
          <div class="art">🎸</div>
          <div class="title">Rumours</div>
          <div class="artist">Fleetwood Mac</div>
        </div>
        <div class="album-card">
          <div class="art">🎷</div>
          <div class="title">Kind of Blue</div>
          <div class="artist">Miles Davis</div>
        </div>
        <div class="album-card">
          <div class="art">🎤</div>
          <div class="title">Thriller</div>
          <div class="artist">Michael Jackson</div>
        </div>
        <div class="album-card">
          <div class="art">🎼</div>
          <div class="title">Abbey Road</div>
          <div class="artist">The Beatles</div>
        </div>
      </div>

      <div class="section-title">Recently Played</div>
      <div class="library-grid">
        <div class="album-card">
          <div class="art">🎧</div>
          <div class="title">Random Access Memories</div>
          <div class="artist">Daft Punk</div>
        </div>
        <div class="album-card">
          <div class="art">🌟</div>
          <div class="title">Currents</div>
          <div class="artist">Tame Impala</div>
        </div>
        <div class="album-card">
          <div class="art">🌈</div>
          <div class="title">OK Computer</div>
          <div class="artist">Radiohead</div>
        </div>
        <div class="album-card">
          <div class="art">⚡</div>
          <div class="title">Back in Black</div>
          <div class="artist">AC/DC</div>
        </div>
      </div>
    </div>

    <!-- Player bar -->
    <div class="player-bar">
      <div class="pb-art">🎵</div>
      <div class="pb-info">
        <div class="title">Bohemian Rhapsody</div>
        <div class="artist">Queen — A Night at the Opera</div>
      </div>
      <div class="pb-controls">
        <button class="pb-btn">🔀</button>
        <button class="pb-btn">⏮</button>
        <button class="pb-btn pb-play">▶</button>
        <button class="pb-btn">⏭</button>
        <button class="pb-btn">🔁</button>
      </div>
      <div class="pb-seek">
        <div class="pb-seek-bar"><div class="pb-seek-fill"></div></div>
        <div class="pb-seek-times">
          <span>2:14</span>
          <span>5:55</span>
        </div>
      </div>
      <div class="pb-volume">
        <span>🔊</span>
        <div class="pb-volume-bar"><div class="pb-volume-fill"></div></div>
      </div>
    </div>
  </div>
</div>

</body>
</html>
"""

OUTPUT.write_text(HTML)
print(f"Wrote {OUTPUT} ({OUTPUT.stat().st_size} bytes)")
