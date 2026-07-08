local Runner = require("./runner")

require("./game_config.spec")(Runner)
require("./monster_catalog.spec")(Runner)
require("./shop_logic.spec")(Runner)
require("./fusion_logic.spec")(Runner)
require("./income_logic.spec")(Runner)

Runner.run()
