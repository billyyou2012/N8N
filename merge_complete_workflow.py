#!/usr/bin/env python3
"""
合併完整 n8n 工作流程腳本
創建選項 B1 的完整工作流程檔案
"""

import json
import sys

def read_json_file(file_path):
    """讀取 JSON 檔案"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"讀取檔案 {file_path} 失敗: {e}")
        return None

def main():
    # 檔案路徑
    original_path = r"C:\AI_Secretary\AI_Secretary.json"
    b1_nodes_path = r"C:\AI_Secretary\AI_Secretary_enhanced_B1.json"
    scheduler_path = r"precise_scheduler_workflow.json"
    output_path = r"C:\AI_Secretary\AI_Secretary_enhanced_B1_complete.json"
    
    print("正在讀取原始工作流程...")
    original = read_json_file(original_path)
    if not original:
        return
    
    print("正在讀取 B1 節點檔案...")
    b1_nodes_data = read_json_file(b1_nodes_path)
    if not b1_nodes_data:
        return
    
    print("正在讀取精確排程工作流程...")
    scheduler = read_json_file(scheduler_path)
    if not scheduler:
        return
    
    # 從 B1 檔案獲取 nodes 陣列
    b1_nodes = b1_nodes_data['nodes']
    print(f"B1 節點數量: {len(b1_nodes)}")
    
    # 從原始檔案獲取基礎結構
    base_structure = {
        "name": "AI_secretary_enhanced_B1",
        "nodes": b1_nodes,
        "pinData": original.get("pinData", {}),
        "connections": {},  # 將合併 connections
        "active": original.get("active", False),
        "settings": original.get("settings", {}),
        "versionId": original.get("versionId", "1.0"),
        "meta": original.get("meta", {}),
        "id": original.get("id", "enhanced_b1"),
        "tags": original.get("tags", [])
    }
    
    # 獲取原始 connections（用戶互動流程）
    original_connections = original.get("connections", {})
    print(f"原始 connections 數量: {len(original_connections)}")
    
    # 獲取排程流程 connections
    scheduler_connections = scheduler.get("connections", {})
    print(f"排程流程 connections 數量: {len(scheduler_connections)}")
    
    # 節點名稱映射（從排程流程到 B1 中的名稱）
    # 注意：B1 檔案中有些節點名稱已更改
    node_name_mapping = {
        "Send Teams Message": "Send Result to Teams",
        # 其他名稱保持不變
    }
    
    # 更新 connections 中的節點名稱
    updated_scheduler_connections = {}
    for node_name, connections in scheduler_connections.items():
        # 映射節點名稱
        mapped_name = node_name_mapping.get(node_name, node_name)
        
        # 更新連接中的節點名稱
        updated_connections = []
        for connection_list in connections.get("main", []):
            updated_list = []
            for connection in connection_list:
                # 映射目標節點名稱
                target_name = node_name_mapping.get(connection["node"], connection["node"])
                updated_connection = connection.copy()
                updated_connection["node"] = target_name
                updated_list.append(updated_connection)
            updated_connections.append(updated_list)
        
        updated_scheduler_connections[mapped_name] = {"main": updated_connections}
    
    print(f"更新後的排程 connections 數量: {len(updated_scheduler_connections)}")
    
    # 合併 connections
    merged_connections = {**original_connections, **updated_scheduler_connections}
    print(f"合併後 connections 總數: {len(merged_connections)}")
    
    # 設置合併後的 connections
    base_structure["connections"] = merged_connections
    
    # 寫入輸出檔案
    print(f"寫入輸出檔案: {output_path}")
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(base_structure, f, ensure_ascii=False, indent=2)
        print("✅ 合併成功完成！")
        print(f"輸出檔案: {output_path}")
        print(f"總節點數: {len(b1_nodes)}")
        print(f"總連接數: {len(merged_connections)}")
        
        # 顯示關鍵連接
        print("\n關鍵連接檢查:")
        print(f"1. Microsoft Teams Trigger → 取頻道對話1: {'Microsoft Teams Trigger' in merged_connections}")
        print(f"2. Precise Schedule Trigger → Get Pending Schedules: {'Precise Schedule Trigger' in merged_connections}")
        print(f"3. Send Result to Teams → Update Status to Completed: {'Send Result to Teams' in merged_connections}")
        
    except Exception as e:
        print(f"寫入輸出檔案失敗: {e}")

if __name__ == "__main__":
    main()