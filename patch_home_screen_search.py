import re

with open('lib/screens/home_screen.dart', 'r') as f:
    c = f.read()

old_search = """                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SearchFullScreen(gigs: allGigs),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'search_bar_hero',"""

new_search = """                child: GestureDetector(
                  onTap: () {
                    context.push('/all-services?search=true');
                  },
                  child: Hero(
                    tag: 'search_bar_hero',"""

c = c.replace(old_search, new_search)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(c)

