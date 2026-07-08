local Runner = require("./tests/runner")

require("./tests/game_config.spec")(Runner)
require("./tests/monster_catalog.spec")(Runner)
require("./tests/shop_logic.spec")(Runner)
require("./tests/fusion_logic.spec")(Runner)
require("./tests/income_logic.spec")(Runner)
require("./tests/scare_mechanic_logic.spec")(Runner)
require("./tests/monster_visual_logic.spec")(Runner)

Runner.run()
