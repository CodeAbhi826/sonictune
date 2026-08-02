"""Tests for sonictune.stats.aggregator (category G — Stats).
"""
from __future__ import annotations

from sonictune.stats.aggregator import StatsAggregator


async def test_stats_empty(db) -> None:
    agg = StatsAggregator(db)
    stats = await agg.get_stats(force_refresh=True)
    assert stats.total_plays == 0
    assert stats.total_listen_ms == 0
    assert stats.unique_tracks == 0
    assert stats.top_tracks == []
    assert stats.top_artists == []
    assert len(stats.listening_by_hour) == 24


async def test_stats_totals(db) -> None:
    agg = StatsAggregator(db, cache_ttl_sec=0)
    await db.upsert_track("a", "Song A", "Artist A")
    await db.upsert_track("b", "Song B", "Artist A")
    await db.upsert_track("c", "Song C", "Artist B")
    await agg.record_play("a", 120000, 95)
    await agg.record_play("a", 60000, 50)
    await agg.record_play("b", 180000, 100)
    await agg.record_play("b", 90000, 75)
    await agg.record_play("c", 30000, 25)

    stats = await agg.get_stats(force_refresh=True)
    assert stats.total_plays == 5
    assert stats.unique_tracks == 3
    assert stats.total_listen_ms == 480000


async def test_stats_top_tracks_sorted(db) -> None:
    agg = StatsAggregator(db, cache_ttl_sec=0)
    for vid, title, ms in [
        ("a", "A", 1000), ("a", "A", 1000), ("a", "A", 1000),
        ("b", "B", 2000), ("b", "B", 2000),
        ("c", "C", 3000),
    ]:
        await db.upsert_track(vid, title, "Artist")
        await agg.record_play(vid, ms, 100)

    stats = await agg.get_stats(force_refresh=True)
    top = stats.top_tracks
    assert top[0]["title"] == "B"  # 4000ms total -> highest listen time
    assert len(top) == 3


async def test_stats_record_play_invalidates_cache(db) -> None:
    agg = StatsAggregator(db, cache_ttl_sec=999)
    await db.upsert_track("a", "A", "Artist A")
    s1 = await agg.get_stats(force_refresh=True)
    assert s1.total_plays == 0
    await agg.record_play("a", 55000, 40)
    s2 = await agg.get_stats()  # should bypass cache
    assert s2.total_plays == 1
