from pathlib import Path


def test_pr_controlled_marker_written():
    assert Path('msrc_safe_marker.json').exists()
