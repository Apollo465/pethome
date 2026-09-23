import { RiskLevel } from '../model/Models';

/**
 * 食物安全知识库（本地、确定性）
 * 说明：判定结果全部来自本表，由本地规则匹配后直接展示，不经过任何模型推断。
 * 主要参考：ASPCA 有毒食物清单、《默克兽医手册》、WSAVA 全球营养指南、临床兽医学常识。
 */
export interface FoodItem {
  id: string;
  name: string;
  aliases: string[];
  /** 'both' 猫狗通用 | 'cat' 仅猫 | 'dog' 仅狗 */
  species: string;
  /** RiskLevel 的值 */
  risk: string;
  /** 一句话结论 */
  summary: string;
  /** 原因 */
  detail: string;
  /** 处理 / 喂食建议 */
  advice: string;
  source: string;
}

const ASPCA = 'ASPCA 有毒食物清单';
const MERCK = '《默克兽医手册》';
const WSAVA = 'WSAVA 全球营养指南';

export const FOOD_ITEMS: FoodItem[] = [
  {
    id: 'chocolate',
    name: '巧克力',
    aliases: ['可可', '黑巧克力', '牛奶巧克力', '巧克力饼干', '酒心巧克力'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '猫狗都不能吃，属于常见中毒原因。',
    detail: '巧克力含可可碱和咖啡因，猫狗代谢这两种物质很慢，会导致心跳加快、兴奋、震颤，严重时抽搐甚至死亡。黑巧克力浓度越高越危险。',
    advice: '误食后立刻记下巧克力种类、大致重量和误食时间，直接联系兽医。不要自行催吐。',
    source: ASPCA
  },
  {
    id: 'grape',
    name: '葡萄',
    aliases: ['葡萄干', '提子', '提子干', '葡萄汁', '葡萄干面包'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '可引起急性肾损伤，一颗也可能出事。',
    detail: '葡萄和葡萄干对犬的肾脏毒性已被广泛证实，猫同样不建议接触。中毒剂量个体差异极大，没有公认的安全量。',
    advice: '误食后按“已中毒”处理，尽快就医查肾功能，不要等待症状出现。',
    source: ASPCA
  },
  {
    id: 'onion',
    name: '洋葱',
    aliases: ['大蒜', '葱', '韭菜', '小葱', '洋葱粉', '蒜粉', '大葱', '蒜蓉', '洋葱汤'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '会破坏红细胞，导致溶血性贫血。',
    detail: '葱属植物含有机硫化物，会氧化红细胞。生的、熟的、粉末的都一样有毒，浓缩的洋葱粉、蒜粉风险更高。炒菜里的葱姜蒜也属于风险来源。',
    advice: '误食量较大或出现精神差、牙龈发白、尿色变深，立即就医。少量误食也应电话咨询兽医。',
    source: MERCK
  },
  {
    id: 'xylitol',
    name: '木糖醇',
    aliases: ['无糖口香糖', '代糖', '木糖醇口香糖', '无糖糖果', '无糖花生酱'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '对犬极危险，可致低血糖和肝衰竭。',
    detail: '木糖醇会让犬胰岛素急剧升高，出现低血糖、站不稳、抽搐，剂量大时造成急性肝损伤。常见于无糖口香糖、无糖糖果、部分牙膏和烘焙食品。',
    advice: '误食后属于急诊，立刻就医，越早处理预后越好。',
    source: ASPCA
  },
  {
    id: 'alcohol',
    name: '酒精',
    aliases: ['啤酒', '白酒', '红酒', '料酒', '酒心巧克力', '醪糟', '酒精饮料'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '剂量很小就可能造成中毒。',
    detail: '猫狗肝脏代谢酒精的能力很弱，会导致共济失调、体温下降、呼吸抑制甚至死亡。除了酒，还要注意含酒精的甜点、发酵面团和部分药品。',
    advice: '误食后立即就医。不要让宠物“尝一口酒”。',
    source: MERCK
  },
  {
    id: 'caffeine',
    name: '咖啡因',
    aliases: ['咖啡', '浓茶', '可乐', '能量饮料', '奶茶', '咖啡因片', '咖啡渣'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '刺激心脏和神经系统，危险性高。',
    detail: '咖啡因会引起心跳加速、烦躁、震颤、呕吐，严重时心律失常和抽搐。咖啡渣、茶包、能量饮料都是常见误食物。',
    advice: '误食后尽快就医，不要喂牛奶“中和”。',
    source: ASPCA
  },
  {
    id: 'macadamia',
    name: '夏威夷果',
    aliases: ['澳洲坚果', 'macadamia'],
    species: 'dog',
    risk: RiskLevel.FORBIDDEN,
    summary: '对犬有明确毒性，少量即可出现症状。',
    detail: '犬在食用后 12 小时内可能出现后肢无力、发抖、发热、呕吐，通常 1-2 天恢复，但高剂量可能更严重。',
    advice: '误食后联系兽医，多数对症处理即可，但不要自行观察太久。',
    source: ASPCA
  },
  {
    id: 'dough',
    name: '生面团',
    aliases: ['未烤面包', '发酵面团', '生面'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '在胃里继续发酵，会产生酒精并胀气。',
    detail: '生面团在体温下持续发酵膨胀，可造成胃扩张，同时产生乙醇导致酒精中毒，属于急诊情况。',
    advice: '立即就医，不要等待症状。',
    source: ASPCA
  },
  {
    id: 'cooked_bone',
    name: '熟骨头',
    aliases: ['鸡骨头', '鸭骨头', '猪骨', '排骨', '禽类骨头'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '加热后易碎裂，会刺伤消化道。',
    detail: '熟禽骨受热后变脆，咬碎成尖锐碎片，可能卡在食道、刺穿胃肠。鱼类细刺同样风险很高。',
    advice: '误食后观察是否有干呕、流口水、拒食、腹痛，出现任一症状立即就医。',
    source: MERCK
  },
  {
    id: 'wild_mushroom',
    name: '野生蘑菇',
    aliases: ['蘑菇', '毒蘑菇', '野蘑菇'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '野外采的蘑菇一律不能喂。',
    detail: '多种野生蘑菇可造成急性肝衰竭或神经症状，且外观难以分辨。',
    advice: '怀疑误食后立即就医，尽量拍下蘑菇照片或保留样本。',
    source: MERCK
  },
  {
    id: 'human_drug',
    name: '人类药物',
    aliases: ['感冒药', '布洛芬', '对乙酰氨基酚', '扑热息痛', '止痛药', '退烧药', '泰诺', '芬必得'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '常见人用药对猫狗可能致命。',
    detail: '对乙酰氨基酚对猫会造成高铁血红蛋白血症和肝损伤；布洛芬等 NSAIDs 可引起犬猫胃溃疡和肾损伤。剂量判断不能靠猜。',
    advice: '不要自行给宠物喂人用药。误食后立即就医，并带走药盒。',
    source: MERCK
  },
  {
    id: 'rodenticide',
    name: '灭鼠药 / 杀虫剂',
    aliases: ['老鼠药', '蟑螂药', '杀虫剂', '农药', '除虫菊酯'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '极危险，且可能延迟发作。',
    detail: '抗凝血类灭鼠药会造成内出血，症状可能延迟数天才出现；除虫菊酯对猫毒性尤其强。',
    advice: '无论有无症状都立即就医，并说明药物名称和可能剂量。',
    source: MERCK
  },
  {
    id: 'lily',
    name: '百合花',
    aliases: ['百合', 'lily', '百合花粉'],
    species: 'cat',
    risk: RiskLevel.FORBIDDEN,
    summary: '对猫剧毒，可致急性肾衰竭。',
    detail: '百合科植物的花瓣、叶子、花粉甚至花瓶里的水对猫都有毒，少量接触即可造成严重肾损伤。',
    advice: '养猫家庭不要摆放百合。怀疑接触后立即就医，越早补液预后越好。',
    source: ASPCA
  },
  {
    id: 'houseplant',
    name: '常见家养植物',
    aliases: ['绿萝', '龟背竹', '滴水观音', '万年青', '芦荟', '富贵竹', '常春藤', '虎皮兰'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '多数观叶植物会刺激口腔和消化道。',
    detail: '绿萝、龟背竹等含草酸钙结晶，啃咬后会出现剧烈流口水、口腔肿痛、呕吐；芦荟可致腹泻。',
    advice: '把植物放在宠物够不到的位置，出现持续流口水或呕吐请就医。',
    source: ASPCA
  },
  {
    id: 'avocado',
    name: '牛油果',
    aliases: ['鳄梨', 'avocado'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '不建议喂，果核与叶皮风险最高。',
    detail: '牛油果含 persin，果皮、叶子、果核对宠物可能造成呕吐腹泻；果核还可能造成肠梗阻。高脂肪也不适合宠物。',
    advice: '不要喂。误食果核请就医评估是否梗阻。',
    source: ASPCA
  },
  {
    id: 'raw_potato',
    name: '生土豆 / 发芽土豆',
    aliases: ['土豆皮', '发芽土豆', '青土豆', '番茄叶', '西红柿茎'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '含龙葵素，会引起消化道和神经症状。',
    detail: '茄科植物的茎叶、未成熟果实和发芽土豆含龙葵素，可致呕吐、腹泻、精神沉郁甚至抽搐。',
    advice: '不要喂生土豆和番茄茎叶。误食后就医。',
    source: MERCK
  },
  {
    id: 'fruit_pit',
    name: '果核与籽',
    aliases: ['苹果核', '樱桃核', '桃核', '杏核', '李子核', '苦杏仁'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '含氰化物前体，且易造成梗阻。',
    detail: '多种蔷薇科果实的核和籽含苦杏仁苷，嚼碎后释放氰化物，可致呼吸困难；核本身也可能卡住肠道。',
    advice: '喂水果务必去核去籽。误食后出现呼吸急促请立即就医。',
    source: ASPCA
  },
  {
    id: 'salty_food',
    name: '高盐与腌制食品',
    aliases: ['火腿', '香肠', '腊肉', '咸菜', '培根', '卤味', '火锅底料', '方便面调料'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '盐分和调味料远超宠物承受范围。',
    detail: '高盐可导致呕吐、腹泻、脱水，极端情况出现钠离子中毒和神经症状。加工肉制品的香辛料和亚硝酸盐同样有害。',
    advice: '不要喂人吃的加工食品。想让宠物“吃点好的”，请选宠物专用零食。',
    source: WSAVA
  },
  {
    id: 'milk',
    name: '牛奶',
    aliases: ['鲜奶', '纯牛奶', '奶油', '奶茶里的奶'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '多数成年猫狗乳糖不耐，容易腹泻。',
    detail: '成年猫狗乳糖酶活性下降，喝牛奶后常出现软便、胀气、腹泻。这不是中毒，但会让肠胃不适。',
    advice: '想给奶制品请选宠物专用羊奶粉或无乳糖奶，少量试喂并观察 24 小时。',
    source: WSAVA
  },
  {
    id: 'cheese',
    name: '奶酪 / 黄油',
    aliases: ['芝士', '黄油', '奶油奶酪'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '少量可接受，高脂高盐是主要问题。',
    detail: '奶酪含乳糖、脂肪和盐，少量对多数宠物无碍，但可能引起软便；长期喂食会增加胰腺炎和肥胖风险。',
    advice: '一次不超过指甲盖大小，软便或呕吐就停。',
    source: WSAVA
  },
  {
    id: 'raw_egg',
    name: '生鸡蛋',
    aliases: ['生蛋', '溏心蛋'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '有细菌风险，生蛋清会影响生物素吸收。',
    detail: '生鸡蛋可能带沙门氏菌；长期大量吃生蛋清会干扰生物素吸收，影响毛发和皮肤。',
    advice: '煮熟再喂，蛋黄和蛋白都可以，不加盐和油。',
    source: WSAVA
  },
  {
    id: 'raw_fish',
    name: '生鱼',
    aliases: ['生三文鱼', '生鱼片', '刺身'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '寄生虫与硫胺素酶风险，建议煮熟。',
    detail: '部分生鱼含硫胺素酶，长期生喂可导致维生素 B1 缺乏；生鱼还可能带寄生虫和细菌。',
    advice: '鱼类煮熟去刺再喂，不加调味。',
    source: WSAVA
  },
  {
    id: 'liver',
    name: '动物肝脏',
    aliases: ['鸡肝', '猪肝', '肝'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '营养丰富但不能多吃。',
    detail: '肝脏富含维生素 A，长期大量喂食可致维生素 A 中毒，影响骨骼和关节；同时胆固醇很高。',
    advice: '每周不超过 1-2 次，每次少量，作为辅食而非主食。',
    source: WSAVA
  },
  {
    id: 'nut',
    name: '坚果（除夏威夷果外）',
    aliases: ['核桃', '杏仁', '腰果', '开心果', '花生', '榛子'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '高脂、易噎，不建议当零食。',
    detail: '坚果脂肪含量高，容易引起胃肠不适甚至胰腺炎，整颗坚果还有窒息和梗阻风险。发霉坚果可能含黄曲霉毒素。',
    advice: '不主动喂。若喂花生酱，必须确认不含木糖醇且无盐无糖。',
    source: WSAVA
  },
  {
    id: 'honey',
    name: '蜂蜜',
    aliases: ['蜂糖', '蜂蜜水'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '本质是糖，少量无益也基本无害。',
    detail: '蜂蜜几乎全是糖分，会升高血糖、增加肥胖和牙齿问题风险。幼年动物不建议喂。',
    advice: '不建议作为日常零食。',
    source: WSAVA
  },
  {
    id: 'citrus',
    name: '柑橘类',
    aliases: ['柠檬', '柚子', '橙子', '橘子', '柑橘'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '果肉少量问题不大，精油和皮要避开。',
    detail: '柑橘果肉少量通常只引起轻微胃肠不适，但果皮中的精油和柠檬酸可能引起呕吐、腹泻和神经系统症状。',
    advice: '不喂皮和精油制品，果肉最多一两小瓣。',
    source: ASPCA
  },
  {
    id: 'fried_food',
    name: '油炸食品',
    aliases: ['炸鸡', '油炸', '薯条', '油条', '烧烤'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '高油高盐，易诱发胰腺炎。',
    detail: '高脂饮食是犬猫急性胰腺炎的重要诱因，表现为剧烈呕吐、腹痛，属于需要住院治疗的疾病。',
    advice: '不要喂。餐桌上的食物一律不喂是更省心的规则。',
    source: WSAVA
  },
  {
    id: 'dessert',
    name: '甜点 / 月饼 / 冰淇淋',
    aliases: ['蛋糕', '月饼', '冰淇淋', '雪糕', '饼干', '奶茶'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '糖、油、乳制品、代糖，风险叠加。',
    detail: '甜点常含木糖醇、巧克力、葡萄干、乳制品和高脂奶油，任一成分都可能造成问题，对宠物没有营养价值。',
    advice: '不要喂。误食含巧克力或木糖醇的甜点按急诊处理。',
    source: ASPCA
  },
  {
    id: 'chicken',
    name: '鸡胸肉（煮熟）',
    aliases: ['鸡胸', '水煮鸡胸', '鸡肉'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '可以吃，前提是无盐无油、煮熟去骨。',
    detail: '去皮鸡胸肉是常见的低脂蛋白来源，适合作为辅食或肠胃不适时的过渡食物。',
    advice: '清水煮熟、撕成小块、不放任何调味；作为辅食，不超过每日总热量的 10%。',
    source: WSAVA
  },
  {
    id: 'salmon_cooked',
    name: '三文鱼（煮熟）',
    aliases: ['熟三文鱼', '鲑鱼'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '优质蛋白与 Omega-3，煮熟去刺即可。',
    detail: '熟三文鱼富含 Omega-3，对皮肤和毛发有好处，但脂肪较高，吃多了会腹泻。',
    advice: '彻底煮熟、去刺、不加调料，每次少量。',
    source: WSAVA
  },
  {
    id: 'egg_yolk',
    name: '熟蛋黄',
    aliases: ['蛋黄', '水煮蛋黄'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '营养好，但要控制量的辅食。',
    detail: '熟蛋黄含卵磷脂和多种维生素，对毛发有帮助，但热量和脂肪偏高。',
    advice: '小型猫犬每周 1-2 个，中大型可适当增加，注意从总热量里扣掉。',
    source: WSAVA
  },
  {
    id: 'pumpkin',
    name: '南瓜（蒸熟）',
    aliases: ['南瓜泥'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '可以吃，对轻度软便有帮助。',
    detail: '南瓜富含可溶性纤维，少量蒸熟南瓜常被用于缓解轻微腹泻或便秘。',
    advice: '蒸熟压成泥，不加糖，每次 1-2 小勺，观察排便变化。',
    source: WSAVA
  },
  {
    id: 'carrot',
    name: '胡萝卜',
    aliases: ['萝卜'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '低热量零食，建议切小块。',
    detail: '胡萝卜纤维丰富、热量低，是常见训练零食，但整根啃食对小型犬有噎住风险。',
    advice: '切成小丁或薄片，生熟皆可，不加调料。',
    source: WSAVA
  },
  {
    id: 'broccoli',
    name: '西兰花',
    aliases: ['花椰菜', '西蓝花'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '可以少量喂，过量会胀气。',
    detail: '西兰花含维生素和纤维，但含异硫氰酸盐，量大可能刺激肠胃。',
    advice: '煮熟切碎，占每日进食量的一小部分即可。',
    source: WSAVA
  },
  {
    id: 'cucumber',
    name: '黄瓜',
    aliases: ['青瓜'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '含水量高、热量低，适合夏天。',
    detail: '黄瓜几乎不含对宠物有害的成分，是低热量零食，但营养有限。',
    advice: '洗净切片直接喂，不加盐。',
    source: WSAVA
  },
  {
    id: 'apple',
    name: '苹果（去核）',
    aliases: ['苹果肉'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '果肉可以吃，核和籽必须去掉。',
    detail: '苹果果肉含纤维和维生素 C，适量无害；但果核和籽含氰化物前体。',
    advice: '去皮去核切小块，一次几块即可。',
    source: ASPCA
  },
  {
    id: 'blueberry',
    name: '蓝莓',
    aliases: ['越橘'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '少量可以，抗氧化但含糖。',
    detail: '蓝莓对宠物无毒，含糖量不低，吃多会软便。',
    advice: '每次几颗，作为训练奖励。',
    source: WSAVA
  },
  {
    id: 'watermelon',
    name: '西瓜（去皮去籽）',
    aliases: ['瓜'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '夏天补水零食，皮和籽不要给。',
    detail: '西瓜含水量高、热量低，但糖分不低，吃多会腹泻。',
    advice: '去皮去籽切小块，一次两三块。',
    source: WSAVA
  },
  {
    id: 'bait',
    name: '宠物零食（商品粮零食）',
    aliases: ['冻干', '肉条', '猫条', '肉干', '饼干'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '可以吃，但要算进每日总热量。',
    detail: '市售零食质量参差，部分含诱食剂、盐和高碳水。零食吃太多会导致主食摄入不足、挑食和肥胖。',
    advice: '零食热量控制在每日总热量的 10% 以内，优先选配料表干净的冻干或肉条。',
    source: WSAVA
  },
  {
    id: 'dogfood_catfood',
    name: '狗粮喂猫 / 猫粮喂狗',
    aliases: ['狗粮', '猫粮'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '偶尔一口无妨，长期喂会营养失衡。',
    detail: '猫是严格肉食动物，需要牛磺酸和花生四烯酸，长期吃狗粮会营养缺乏；狗吃猫粮则容易热量和蛋白超标。',
    advice: '不要长期交叉喂食，临时应急吃一两顿没问题。',
    source: WSAVA
  },
  {
    id: 'sugar_free_yogurt',
    name: '无糖酸奶',
    aliases: ['酸奶', '希腊酸奶'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '关键看代糖，含木糖醇的一律不能喂。',
    detail: '少量原味酸奶多数宠物可以耐受，但乳糖仍可能引起软便；如果含木糖醇则对犬有生命危险。',
    advice: '只喂原味无糖（不含代糖）酸奶，一小勺试起。',
    source: ASPCA
  },
  {
    id: 'rice',
    name: '米饭 / 白粥',
    aliases: ['白米饭', '稀饭', '小米粥'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '肠胃不适时可短期吃，不适合长期当主食。',
    detail: '米饭易消化，常在腹泻时与鸡胸肉一起做过渡饮食，但营养单一，长期喂会缺蛋白和微量元素。',
    advice: '作为 2-3 天的过渡饮食可以，之后逐步换回正常主食。',
    source: WSAVA
  },
  {
    id: 'catnip',
    name: '猫薄荷',
    aliases: ['猫草', '木天蓼'],
    species: 'cat',
    risk: RiskLevel.SAFE,
    summary: '对猫安全，可帮助排毛球。',
    detail: '猫薄荷和猫草对猫无毒，能让猫放松、促进活动，猫草纤维还有助于吐出毛球。',
    advice: '适量即可，部分猫无反应属正常。',
    source: WSAVA
  },
  {
    id: 'sweet_potato',
    name: '红薯（蒸熟）',
    aliases: ['地瓜', '番薯'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '可以少量喂，必须蒸熟去皮。',
    detail: '蒸熟红薯纤维和 β-胡萝卜素丰富，但含糖和碳水较高，吃多会胀气腹泻。',
    advice: '蒸熟去皮压泥，每次一小勺。',
    source: WSAVA
  },
  {
    id: 'strawberry',
    name: '草莓',
    aliases: ['树莓', '覆盆子'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '少量可以，含糖不低。',
    detail: '草莓对宠物无毒，含维生素 C 和纤维，但糖分较高。',
    advice: '洗净去蒂，一次一到两颗。',
    source: WSAVA
  },
  {
    id: 'coconut',
    name: '椰子 / 椰子油',
    aliases: ['椰肉', '椰汁'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '少量椰肉可以，椰汁和大量椰子油不建议。',
    detail: '新鲜椰肉少量通常无害，但脂肪高易腹泻；市售椰汁多含糖，椰子油大量喂会引发胰腺炎风险。',
    advice: '只喂极少量新鲜椰肉，不喂含糖椰汁。',
    source: ASPCA
  },
  {
    id: 'sausage',
    name: '火腿肠 / 午餐肉',
    aliases: ['热狗', '肉肠'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '盐、添加剂和脂肪都超标。',
    detail: '火腿肠含盐、亚硝酸盐、增味剂和大量脂肪，长期或大量喂食会造成钠摄入过量、胰腺负担和挑食。',
    advice: '不要作为零食。训练奖励请用宠物专用肉条。',
    source: WSAVA
  },
  {
    id: 'bone_soup',
    name: '骨头汤 / 肉汤',
    aliases: ['大骨汤', '肉汤', '鸡汤'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '不加盐的清汤可以少量，油脂要撇掉。',
    detail: '长时间熬煮的骨汤脂肪和嘌呤高，且常加盐和洋葱调味，这些都对宠物有害。',
    advice: '只喂无盐无葱姜、撇净浮油的清汤，或直接用水煮肉汤拌粮。',
    source: WSAVA
  },
  {
    id: 'corn',
    name: '玉米',
    aliases: ['玉米粒', '玉米棒'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '玉米粒少量可以，玉米芯绝对不能吃。',
    detail: '玉米本身无毒，但营养以碳水为主；玉米芯不易消化，是犬肠道梗阻的常见原因。',
    advice: '只喂少量煮熟的玉米粒，玉米芯请直接丢弃。',
    source: WSAVA
  },
  {
    id: 'oat',
    name: '燕麦',
    aliases: ['燕麦片', '麦片'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '少数宠物可以，属于高碳水食物。',
    detail: '无糖纯燕麦片少量对多数宠物无害，但碳水高、纤维多，吃多会胀气腹泻。',
    advice: '只喂无糖原味、煮熟的少量燕麦。',
    source: WSAVA
  },
  {
    id: 'banana',
    name: '香蕉',
    aliases: ['芭蕉'],
    species: 'both',
    risk: RiskLevel.CAUTION,
    summary: '可以少量，糖分偏高。',
    detail: '香蕉富含钾和糖，少量无害，吃多会软便，糖尿病或肥胖宠物应避免。',
    advice: '每次一两片，作为偶尔的奖励。',
    source: WSAVA
  },
  {
    id: 'toothpaste',
    name: '人用牙膏',
    aliases: ['牙膏', '漱口水'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '含木糖醇和氟化物，不能给宠物用。',
    detail: '人用牙膏常含木糖醇、氟化物和薄荷精油，误食会导致低血糖或胃肠损伤。',
    advice: '请使用宠物专用牙膏。误食后按木糖醇中毒处理。',
    source: ASPCA
  },
  {
    id: 'hand_sanitizer',
    name: '洗手液 / 消毒液 / 精油',
    aliases: ['酒精湿巾', '消毒水', '茶树精油', '精油'],
    species: 'both',
    risk: RiskLevel.FORBIDDEN,
    summary: '含酒精、酚类或精油，误食危险。',
    detail: '多种精油（茶树、薄荷、柑橘、冬青）对猫代谢负担极大，酒精和酚类消毒剂可致口腔灼伤和中毒。',
    advice: '使用后擦净宠物可能舔到的表面，误食后就医。',
    source: ASPCA
  },
  {
    id: 'pet_milk',
    name: '宠物羊奶粉',
    aliases: ['羊奶粉', '宠物奶粉'],
    species: 'both',
    risk: RiskLevel.SAFE,
    summary: '幼宠可用，成宠按说明少量。',
    detail: '宠物专用羊奶粉乳糖含量经调整，比牛奶更适合幼猫幼犬；但成宠喝多同样会腹泻。',
    advice: '按产品说明冲调，幼宠按体重计算，成宠当零食少量。',
    source: WSAVA
  }
];

/** 按名称或别名搜索，返回匹配度排序的结果 */
export function searchFood(keyword: string): FoodItem[] {
  const query = keyword.trim().toLowerCase();
  if (query.length === 0) {
    return [];
  }
  const exact: FoodItem[] = [];
  const partial: FoodItem[] = [];
  for (let i = 0; i < FOOD_ITEMS.length; i++) {
    const item = FOOD_ITEMS[i];
    if (item.name.toLowerCase() === query) {
      exact.push(item);
      continue;
    }
    let matched = item.name.toLowerCase().indexOf(query) >= 0;
    if (!matched) {
      for (let j = 0; j < item.aliases.length; j++) {
        if (item.aliases[j].toLowerCase().indexOf(query) >= 0) {
          matched = true;
          break;
        }
      }
    }
    if (matched) {
      partial.push(item);
    }
  }
  return exact.concat(partial);
}

/** 从一整句问题里找出提到的食物（最长的匹配优先） */
export function findFoodInText(text: string): FoodItem | undefined {
  const content = text.toLowerCase();
  let best: FoodItem | undefined = undefined;
  let bestLength = 0;
  for (let i = 0; i < FOOD_ITEMS.length; i++) {
    const item = FOOD_ITEMS[i];
    const candidates: string[] = [item.name];
    for (let j = 0; j < item.aliases.length; j++) {
      candidates.push(item.aliases[j]);
    }
    for (let k = 0; k < candidates.length; k++) {
      const word = candidates[k].toLowerCase();
      if (word.length > bestLength && content.indexOf(word) >= 0) {
        bestLength = word.length;
        best = item;
      }
    }
  }
  return best;
}

export function foodById(id: string): FoodItem | undefined {
  for (let i = 0; i < FOOD_ITEMS.length; i++) {
    if (FOOD_ITEMS[i].id === id) {
      return FOOD_ITEMS[i];
    }
  }
  return undefined;
}

/** 高风险条目，用于首页快捷入口 */
export function forbiddenFoods(): FoodItem[] {
  const result: FoodItem[] = [];
  for (let i = 0; i < FOOD_ITEMS.length; i++) {
    if (FOOD_ITEMS[i].risk === RiskLevel.FORBIDDEN) {
      result.push(FOOD_ITEMS[i]);
    }
  }
  return result;
}

export function riskyIds(): string[] {
  return [
    'chocolate', 'grape', 'onion', 'xylitol', 'alcohol', 'caffeine',
    'lily', 'macadamia', 'human_drug', 'rodenticide'
  ];
}
