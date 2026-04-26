extends RefCounted
class_name BuilderCatalog


static func create_default_catalog() -> Array[Dictionary]:
	return [
		{
			"id": "mingju",
			"name": "民居类",
			"category": "民生建筑",
			"summary": "柴米油盐皆日子，琴棋书画亦家常。——民居之朴，自古而然。
用于安置居民、提供基础生活空间的标推民居单元\n
一室虽朴，可安身心；一屋虽简，能纳烟火\n\n
民居类建筑承担聚落扩展时最基础的人口承载功能\n
安顿黎庶，起居之需，凡聚落欲拓，乃众庶所依\n\n
完成建造后可作为居民入住、生活组织和后续社区扩建的起点\n
建成之时，纳民入户，理其生息，为日后社区增扩之发端\n\n
这间民居基础结构用的是抬梁式，抬梁式就是先在柱子上架大梁，梁上再立短柱、放小梁，一层层抬上去，撑起屋顶。
墙体一般用青砖砌成空斗墙，屋顶铺小青瓦，做成硬山式，堂屋的大门朝南开，窗户开在前后墙上，方便通风采光。",
			"description": "民居类建筑采用徽式建筑结构，使用矿石粉和金属材料修建马头墙，以提高建筑的防火性能。穿斗式钢结构，通过穿枋连接柱子，提高建筑的抗震性能。承担聚落扩展时最基础的人口承载功能。\n\n完成建造后可作为居民入住、生活组织和后续社区扩建的起点。",
			"build_label": "建造民居",
			"image_path": "res://resources/build_pic/tingyuan.png",
			"built": false,
			"materials": [
				{"id": "ore_powder", "name": "矿石粉", "category": "基础材料", "required_amount": 2000, "submitted_amount": 0},
				{"id": "water", "name": "水", "category": "基础资源", "required_amount": 5000, "submitted_amount": 0},
				{"id": "high_purity_metal_block", "name": "高纯金属块", "category": "精炼材料", "required_amount": 2000, "submitted_amount": 0}
			]
		},
		{
			"id": "百纳仓",
			"name": "仓库类",
			"category": "储运建筑",
			"summary": "用于集中存放工业物资、稳定区域周转效率的仓储设施。",
			"description": "仓库类建筑负责承接大宗材料与稀有物资的集中管理。\n\n建造完成后更适合作为生产区和运输节点之间的缓冲设施。",
			"build_label": "建造仓库",
			"image_path": "res://resources/build_pic/cangku.png",
			"built": false,
			"materials": [
				{"id": "high_purity_metal_block", "name": "高纯金属块", "category": "精炼材料", "required_amount": 5000, "submitted_amount": 0},
				{"id": "rare_metal_block", "name": "稀有金属块", "category": "稀有材料", "required_amount": 1000, "submitted_amount": 0}
			]
		},
		{
			"id": "栖迟庭",
			"name": "庭院类",
			"category": "景观建筑",
			"summary": "广厦千间眠七尺，庭院一隅赏四时。”——庭院之雅，自古而然。
兼顾居住品质与公共活动的庭院式景观建筑\n
既安居家常之暖，亦容邻里欢语之乐\n\n

庭院类建筑偏向环境塑造和区域宜居度提升\n
以草木为笔、光阴为墨，勾勒宜居之境\n\n

它通常用于居住区中心或连接多个功能区，提供缓冲、休憩和景观空间\n
居于坊间之心，连缀四方之所；缓往来之匆匆，安尘劳之倦乏\n\n



这座庭院的搭建，整体布局讲究“四合”，从东、南、西、北四面围起来，中间留出一块露天的地方。
院子的主屋一般采用抬梁式木构架，柱子上架梁，梁上再立短柱，层层抬起来，撑起屋顶。
屋顶多用硬山或悬山式，铺小青瓦，檐口挑出浅浅的一截，既能遮阳又能避雨。",
			"description": "采用唐朝时期的街道布局，加以现代化的古风建筑风格，在保留传统文化内核的同时，让传统建筑在观感上不“古”。\n\n它通常用于商业区中心或连接多个功能区，提供缓冲、休憩和景观空间。",
			"build_label": "建造庭院",
			"image_path": "res://resources/build_pic/Mingju.png",
			"built": false,
			"materials": [
				{"id": "ore_powder", "name": "矿石粉", "category": "基础材料", "required_amount": 5000, "submitted_amount": 0},
				{"id": "water", "name": "水", "category": "基础资源", "required_amount": 10000, "submitted_amount": 0},
				{"id": "high_purity_metal_block", "name": "高纯金属块", "category": "精炼材料", "required_amount": 3000, "submitted_amount": 0}
			]
		}
	]
