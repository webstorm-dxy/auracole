using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Auracole.IndustryMap.Data;

/// <summary>
/// 负责将运行时快照与 Godot 可序列化字典结构互相转换。
/// </summary>
public static class ProductionSerialization
{
	/// <summary>
	/// 将顶层快照文件转换为 Godot 字典，便于写入 JSON。
	/// </summary>
	public static Godot.Collections.Dictionary SerializeSnapshotFile(ProductionSnapshotFile snapshotFile)
	{
		Godot.Collections.Array machines = [];
		foreach (MachineSnapshot machine in snapshotFile.Machines)
		{
			machines.Add(SerializeMachineSnapshot(machine));
		}

		return new Godot.Collections.Dictionary
		{
			{ "logout_unix_time", snapshotFile.LogoutUnixTime },
			{ "machines", machines }
		};
	}

	/// <summary>
	/// 从 Godot 字典恢复顶层快照文件。
	/// </summary>
	public static ProductionSnapshotFile DeserializeSnapshotFile(Godot.Collections.Dictionary dictionary)
	{
		Godot.Collections.Array machineArray = dictionary.ContainsKey("machines")
			? ((Variant)dictionary["machines"]).AsGodotArray()
			: [];

		List<MachineSnapshot> machines = new(machineArray.Count);
		foreach (Variant machineVariant in machineArray)
		{
			machines.Add(DeserializeMachineSnapshot(machineVariant.AsGodotDictionary()));
		}

		return new ProductionSnapshotFile
		{
			LogoutUnixTime = dictionary.ContainsKey("logout_unix_time")
				? ((Variant)dictionary["logout_unix_time"]).AsInt64()
				: 0,
			Machines = machines.ToArray()
		};
	}

	/// <summary>
	/// 将单台机器快照转换为 Godot 字典。
	/// </summary>
	public static Godot.Collections.Dictionary SerializeMachineSnapshot(MachineSnapshot snapshot)
	{
		Godot.Collections.Array routes = [];
		foreach (MachineRoute route in snapshot.OutputRoutes.OrderBy(route => route.Priority).ThenBy(route => route.TargetMachineId, StringComparer.Ordinal))
		{
			routes.Add(new Godot.Collections.Dictionary
			{
				{ "item_id", route.ItemId },
				{ "target_machine_id", route.TargetMachineId },
				{ "target_input_item_id", route.TargetInputItemId },
				{ "priority", route.Priority }
			});
		}

		return new Godot.Collections.Dictionary
		{
			{ "machine_id", snapshot.MachineId },
			{ "display_name", snapshot.DisplayName },
			{ "recipe", SerializeRecipe(snapshot.Recipe) },
			{ "state", snapshot.State.ToString() },
			{ "progress_seconds", snapshot.ProgressSeconds },
			{ "auto_start", snapshot.AutoStart },
			{ "input_buffer", SerializeStringIntDictionary(snapshot.InputBuffer) },
			{ "output_buffer", SerializeStringIntDictionary(snapshot.OutputBuffer) },
			{ "pending_output_buffer", SerializeStringIntDictionary(snapshot.PendingOutputBuffer) },
			{ "input_capacity", SerializeStringIntDictionary(snapshot.InputCapacity) },
			{ "output_capacity", SerializeStringIntDictionary(snapshot.OutputCapacity) },
			{ "output_routes", routes },
			{ "sort_order", snapshot.SortOrder }
		};
	}

	/// <summary>
	/// 从 Godot 字典恢复单台机器快照。
	/// </summary>
	public static MachineSnapshot DeserializeMachineSnapshot(Godot.Collections.Dictionary dictionary)
	{
		List<MachineRoute> routes = [];
		Godot.Collections.Array routeArray = dictionary.ContainsKey("output_routes")
			? ((Variant)dictionary["output_routes"]).AsGodotArray()
			: [];

		foreach (Variant routeVariant in routeArray)
		{
			Godot.Collections.Dictionary routeDict = routeVariant.AsGodotDictionary();
			routes.Add(new MachineRoute
			{
				ItemId = routeDict.ContainsKey("item_id") ? ((Variant)routeDict["item_id"]).AsString() : string.Empty,
				TargetMachineId = routeDict.ContainsKey("target_machine_id") ? ((Variant)routeDict["target_machine_id"]).AsString() : string.Empty,
				TargetInputItemId = routeDict.ContainsKey("target_input_item_id") ? ((Variant)routeDict["target_input_item_id"]).AsString() : string.Empty,
				Priority = routeDict.ContainsKey("priority") ? ((Variant)routeDict["priority"]).AsInt32() : 0
			});
		}

		string stateName = dictionary.ContainsKey("state") ? ((Variant)dictionary["state"]).AsString() : nameof(MachineState.Idle);
		if (!Enum.TryParse(stateName, true, out MachineState machineState))
		{
			machineState = MachineState.Idle;
		}

		return new MachineSnapshot
		{
			MachineId = dictionary.ContainsKey("machine_id") ? ((Variant)dictionary["machine_id"]).AsString() : string.Empty,
			DisplayName = dictionary.ContainsKey("display_name") ? ((Variant)dictionary["display_name"]).AsString() : string.Empty,
			Recipe = dictionary.ContainsKey("recipe") ? DeserializeRecipe(((Variant)dictionary["recipe"]).AsGodotDictionary()) : new Recipe(),
			State = machineState,
			ProgressSeconds = dictionary.ContainsKey("progress_seconds") ? ((Variant)dictionary["progress_seconds"]).AsSingle() : 0.0f,
			AutoStart = !dictionary.ContainsKey("auto_start") || ((Variant)dictionary["auto_start"]).AsBool(),
			InputBuffer = DeserializeStringIntDictionary(dictionary, "input_buffer"),
			OutputBuffer = DeserializeStringIntDictionary(dictionary, "output_buffer"),
			PendingOutputBuffer = DeserializeStringIntDictionary(dictionary, "pending_output_buffer"),
			InputCapacity = DeserializeStringIntDictionary(dictionary, "input_capacity"),
			OutputCapacity = DeserializeStringIntDictionary(dictionary, "output_capacity"),
			OutputRoutes = routes,
			SortOrder = dictionary.ContainsKey("sort_order") ? ((Variant)dictionary["sort_order"]).AsInt32() : 0
		};
	}

	/// <summary>
	/// 将配方对象序列化为 Godot 字典。
	/// </summary>
	public static Godot.Collections.Dictionary SerializeRecipe(Recipe recipe)
	{
		return new Godot.Collections.Dictionary
		{
			{ "id", recipe.Id },
			{ "cycle_time", recipe.CycleTime },
			{ "inputs", SerializeStringIntDictionary(recipe.Inputs) },
			{ "outputs", SerializeStringIntDictionary(recipe.Outputs) }
		};
	}

	/// <summary>
	/// 从 Godot 字典恢复配方对象。
	/// </summary>
	public static Recipe DeserializeRecipe(Godot.Collections.Dictionary dictionary)
	{
		return new Recipe
		{
			Id = dictionary.ContainsKey("id") ? ((Variant)dictionary["id"]).AsString() : string.Empty,
			CycleTime = dictionary.ContainsKey("cycle_time") ? ((Variant)dictionary["cycle_time"]).AsSingle() : 1.0f,
			Inputs = DeserializeStringIntDictionary(dictionary, "inputs"),
			Outputs = DeserializeStringIntDictionary(dictionary, "outputs")
		};
	}

	/// <summary>
	/// 序列化字符串到整数的字典，并按键排序确保输出稳定。
	/// </summary>
	public static Godot.Collections.Dictionary SerializeStringIntDictionary(IReadOnlyDictionary<string, int> dictionary)
	{
		Godot.Collections.Dictionary serialized = [];
		foreach (KeyValuePair<string, int> pair in dictionary.OrderBy(pair => pair.Key, StringComparer.Ordinal))
		{
			serialized[pair.Key] = pair.Value;
		}

		return serialized;
	}

	/// <summary>
	/// 从根字典的指定键读取字符串到整数的字典。
	/// </summary>
	public static Dictionary<string, int> DeserializeStringIntDictionary(Godot.Collections.Dictionary root, string key)
	{
		if (!root.ContainsKey(key))
		{
			return new Dictionary<string, int>(StringComparer.Ordinal);
		}

		return DeserializeStringIntDictionary(((Variant)root[key]).AsGodotDictionary());
	}

	/// <summary>
	/// 直接从 Godot 字典恢复字符串到整数的字典。
	/// </summary>
	public static Dictionary<string, int> DeserializeStringIntDictionary(Godot.Collections.Dictionary dictionary)
	{
		Dictionary<string, int> result = new(StringComparer.Ordinal);
		foreach (Variant keyVariant in dictionary.Keys)
		{
			string key = keyVariant.AsString();
			result[key] = ((Variant)dictionary[key]).AsInt32();
		}

		return result;
	}
}
