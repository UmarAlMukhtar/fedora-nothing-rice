import unittest
from desktop_host import browser_is_away, hyprland_browser_is_away
class HostTests(unittest.TestCase):
    def test_away_and_sticky_pip_do_not_count_as_main_browser(self):
        normal={'id':10,'client':{'className':'Brave-browser'},'hidden':False}
        pip={'id':11,'client':{'className':'Brave-browser'},'hidden':False}
        tree={'monitors':[{'focusedDesktopId':1,'desktops':[{'id':1,'root':pip},{'id':2,'root':normal}]}]}
        title=lambda wid:'Picture in picture' if wid==11 else 'YouTube - Brave'
        self.assertTrue(browser_is_away(tree,title))
        tree['monitors'][0]['focusedDesktopId']=2
        self.assertFalse(browser_is_away(tree,title))

    def test_hyprland_ignores_pinned_pip_and_tracks_the_visible_browser_workspace(self):
        monitors = [{"activeWorkspace": {"name": "1"}, "specialWorkspace": {"name": ""}}]
        normal = {"class": "brave-browser", "title": "Video - Brave", "mapped": True, "workspace": {"name": "2"}}
        pip = {**normal, "title": "Picture in picture", "pinned": True}
        self.assertTrue(hyprland_browser_is_away([normal, pip], monitors))
        monitors[0]["activeWorkspace"]["name"] = "2"
        self.assertFalse(hyprland_browser_is_away([normal, pip], monitors))
        normal["hidden"] = True
        self.assertTrue(hyprland_browser_is_away([normal, pip], monitors))
