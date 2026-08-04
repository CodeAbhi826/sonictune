"""Tests for the SyncedLyricsView QML component."""

import pytest
from PySide6.QtCore import QUrl

try:
    from PySide6.QtQuickTest import QtQuickTest as QQuickTest
except ImportError:
    QQuickTest = None

if QQuickTest is None:
    pytest.skip("QtQuickTest not available in this PySide6 build", allow_module_level=True)


class TestSyncedLyricsView(QQuickTest):
    """Test the SyncedLyricsView QML component."""

    @pytest.fixture
    def qml_url(self):
        return QUrl.fromLocalFile(
            "src/sonictune/ui/qml/components/SyncedLyricsView.qml"
        )

    def test_component_creation(self, qml_url):
        """Test that the component can be created."""
        # This test verifies that the QML component can be loaded without errors
        # It doesn't test the functionality, just that the component is valid
        self.engine.load(qml_url)
        assert not self.engine.rootObjects().isEmpty()

    def test_empty_state(self, qml_url):
        """Test the empty state of the lyrics view."""
        self.engine.load(qml_url)
        root = self.engine.rootObjects()[0]
        
        # Should be in empty state initially
        assert root.property("model").toVariant() == []
        
        # Empty state should be visible
        empty_state = root.findChild(root, "emptyState")
        assert empty_state is not None
        assert empty_state.isVisible()

    def test_lyrics_display(self, qml_url):
        """Test displaying lyrics."""
        self.engine.load(qml_url)
        root = self.engine.rootObjects()[0]
        
        # Set a test model
        test_model = [
            {"time_ms": 0, "text": "First line"},
            {"time_ms": 2000, "text": "Second line"},
            {"time_ms": 4000, "text": "Third line"}
        ]
        root.setProperty("model", test_model)
        
        # Empty state should be hidden
        empty_state = root.findChild(root, "emptyState")
        assert not empty_state.isVisible()
        
        # Should have 3 lyric lines
        lyrics_list = root.findChild(root, "lyricsList")
        assert lyrics_list is not None
        assert lyrics_list.property("count") == 3

    def test_current_position_highlight(self, qml_url):
        """Test that the current position highlights the correct line."""
        self.engine.load(qml_url)
        root = self.engine.rootObjects()[0]
        
        # Set a test model
        test_model = [
            {"time_ms": 0, "text": "First line"},
            {"time_ms": 2000, "text": "Second line"},
            {"time_ms": 4000, "text": "Third line"}
        ]
        root.setProperty("model", test_model)
        
        # Set current position to 1500ms (should highlight first line)
        root.setProperty("currentPositionMs", 1500)
        
        lyrics_list = root.findChild(root, "lyricsList")
        assert lyrics_list is not None
        
        # First line should be active
        first_delegate = lyrics_list.itemAtIndex(0)
        assert first_delegate is not None
        assert first_delegate.property("isActive")
        
        # Second line should not be active
        second_delegate = lyrics_list.itemAtIndex(1)
        assert second_delegate is not None
        assert not second_delegate.property("isActive")
        
        # Set current position to 3000ms (should highlight second line)
        root.setProperty("currentPositionMs", 3000)
        
        # Second line should now be active
        assert second_delegate.property("isActive")
        assert not first_delegate.property("isActive")