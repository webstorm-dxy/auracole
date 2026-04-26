using System;
using System.Collections.Generic;
using System.Linq;

namespace Auracole.IndustryMap.Data;

/// <summary>
/// 描述单台机器在离线推演中的离散状态。
/// </summary>
public enum MachineState
{
	Idle,
	Processing,
	InputBlocked,
	OutputBlocked
}

/// <summary>
/// 定义一种物品的基础静态数据。
/// </summary>
public sealed class Item
{
	/// <summary>
	/// 物品唯一标识。
	/// </summary>
	public string Id { get; set; } = string.Empty;

	/// <summary>
	/// 用于 UI 展示的人类可读名称。
	/// </summary>
	public string Name { get; set; } = string.Empty;

	/// <summary>
	/// 单个堆叠允许的最大数量。
	/// </summary>
	public int MaxStack { get; set; } = 999;

	/// <summary>
	/// 创建当前物品定义的深拷贝，避免运行时共享同一引用。
	/// </summary>
	public Item DeepClone()
	{
		return new Item
		{
			Id = Id,
			Name = Name,
			MaxStack = MaxStack
		};
	}
}

/// <summary>
/// 定义生产配方，包括单次周期时长、输入物料和输出物料。
/// </summary>
public sealed class Recipe
{
	/// <summary>
	/// 配方唯一标识。
	/// </summary>
	public string Id { get; set; } = string.Empty;

	/// <summary>
	/// 单次生产周期所需秒数。
	/// </summary>
	public float CycleTime { get; set; } = 1.0f;

	/// <summary>
	/// 单次开工时一次性消耗的输入物料。
	/// </summary>
	public Dictionary<string, int> Inputs { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 单次完工时一次性生成的输出物料。
	/// </summary>
	public Dictionary<string, int> Outputs { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 创建配方的深拷贝，确保字典不会被外部复用。
	/// </summary>
	public Recipe DeepClone()
	{
		return new Recipe
		{
			Id = Id,
			CycleTime = CycleTime,
			Inputs = new Dictionary<string, int>(Inputs, StringComparer.Ordinal),
			Outputs = new Dictionary<string, int>(Outputs, StringComparer.Ordinal)
		};
	}
}

/// <summary>
/// 描述一条输出路由，将某种产物发送到下游机器的指定输入口。
/// </summary>
public sealed class MachineRoute
{
	/// <summary>
	/// 要路由的物品标识。
	/// </summary>
	public string ItemId { get; set; } = string.Empty;

	/// <summary>
	/// 下游目标机器标识。
	/// </summary>
	public string TargetMachineId { get; set; } = string.Empty;

	/// <summary>
	/// 下游输入口物品标识；为空时沿用输出物品标识。
	/// </summary>
	public string TargetInputItemId { get; set; } = string.Empty;

	/// <summary>
	/// 路由优先级，值越小越优先。
	/// </summary>
	public int Priority { get; set; }

	/// <summary>
	/// 创建路由定义的深拷贝。
	/// </summary>
	public MachineRoute DeepClone()
	{
		return new MachineRoute
		{
			ItemId = ItemId,
			TargetMachineId = TargetMachineId,
			TargetInputItemId = TargetInputItemId,
			Priority = Priority
		};
	}
}

/// <summary>
/// 表示单台机器可被序列化的完整快照。
/// </summary>
public sealed class MachineSnapshot
{
	/// <summary>
	/// 机器唯一标识。
	/// </summary>
	public string MachineId { get; set; } = string.Empty;

	/// <summary>
	/// 机器显示名称。
	/// </summary>
	public string DisplayName { get; set; } = string.Empty;

	/// <summary>
	/// 当前绑定的生产配方。
	/// </summary>
	public Recipe Recipe { get; set; } = new();

	/// <summary>
	/// 当前离散状态。
	/// </summary>
	public MachineState State { get; set; } = MachineState.Idle;

	/// <summary>
	/// 当前配方已累计的加工进度，单位为秒。
	/// </summary>
	public float ProgressSeconds { get; set; }

	/// <summary>
	/// 是否允许在满足条件时自动开工。
	/// </summary>
	public bool AutoStart { get; set; } = true;

	/// <summary>
	/// 输入缓存区。
	/// </summary>
	public Dictionary<string, int> InputBuffer { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 可直接被外部取走或继续路由的输出缓存区。
	/// </summary>
	public Dictionary<string, int> OutputBuffer { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 因背压未能完全写入输出缓存区的暂存结果。
	/// </summary>
	public Dictionary<string, int> PendingOutputBuffer { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 输入缓存区容量限制。
	/// </summary>
	public Dictionary<string, int> InputCapacity { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 输出缓存区容量限制。
	/// </summary>
	public Dictionary<string, int> OutputCapacity { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 输出到下游的路由表。
	/// </summary>
	public List<MachineRoute> OutputRoutes { get; set; } = [];

	/// <summary>
	/// 用于稳定排序，保证同条件下的处理顺序可重复。
	/// </summary>
	public int SortOrder { get; set; }

	/// <summary>
	/// 创建机器快照的深拷贝，避免离线推演污染场景原始数据。
	/// </summary>
	public MachineSnapshot DeepClone()
	{
		return new MachineSnapshot
		{
			MachineId = MachineId,
			DisplayName = DisplayName,
			Recipe = Recipe.DeepClone(),
			State = State,
			ProgressSeconds = ProgressSeconds,
			AutoStart = AutoStart,
			InputBuffer = new Dictionary<string, int>(InputBuffer, StringComparer.Ordinal),
			OutputBuffer = new Dictionary<string, int>(OutputBuffer, StringComparer.Ordinal),
			PendingOutputBuffer = new Dictionary<string, int>(PendingOutputBuffer, StringComparer.Ordinal),
			InputCapacity = new Dictionary<string, int>(InputCapacity, StringComparer.Ordinal),
			OutputCapacity = new Dictionary<string, int>(OutputCapacity, StringComparer.Ordinal),
			OutputRoutes = OutputRoutes.Select(route => route.DeepClone()).ToList(),
			SortOrder = SortOrder
		};
	}
}

/// <summary>
/// 封装一次离线推演的输出结果。
/// </summary>
public sealed class SimulationResult
{
	/// <summary>
	/// 推演结束后的机器快照集合。
	/// </summary>
	public MachineSnapshot[] FinalSnapshots { get; set; } = Array.Empty<MachineSnapshot>();

	/// <summary>
	/// 本次离线期间累计产出的物品统计。
	/// </summary>
	public Dictionary<string, int> TotalProduced { get; set; } = new(StringComparer.Ordinal);

	/// <summary>
	/// 实际被推演的秒数。
	/// </summary>
	public float SimulatedSeconds { get; set; }

	/// <summary>
	/// 被消费的定时事件数量。
	/// </summary>
	public int ProcessedTimedEvents { get; set; }

	/// <summary>
	/// 是否因为进入稳态或到达终止阈值而结束。
	/// </summary>
	public bool ReachedSteadyState { get; set; }
}

/// <summary>
/// 序列化到磁盘的顶层快照文件结构。
/// </summary>
public sealed class ProductionSnapshotFile
{
	/// <summary>
	/// 玩家下线时的 Unix 时间戳。
	/// </summary>
	public long LogoutUnixTime { get; set; }

	/// <summary>
	/// 下线瞬间的全部机器快照。
	/// </summary>
	public MachineSnapshot[] Machines { get; set; } = Array.Empty<MachineSnapshot>();

	/// <summary>
	/// 创建整个快照文件的深拷贝。
	/// </summary>
	public ProductionSnapshotFile DeepClone()
	{
		return new ProductionSnapshotFile
		{
			LogoutUnixTime = LogoutUnixTime,
			Machines = Machines.Select(machine => machine.DeepClone()).ToArray()
		};
	}
}
