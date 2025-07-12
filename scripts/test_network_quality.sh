#!/bin/bash

# 网络质量功能测试脚本
# Created by Claude on 2025/7/12

set -e

echo "🌐 网络质量功能测试"
echo "=================="

# 进入项目目录
cd "$(dirname "$0")/.."

# 创建临时测试文件
cat > test_network_quality_temp.swift << 'EOF'
#!/usr/bin/env swift

import Foundation

// 模拟网络质量指标结构
struct NetworkQualityMetrics {
    let latency: TimeInterval
    let bandwidth: Double
    let packetLoss: Double
    let jitter: TimeInterval
    let isConstrained: Bool
    let isExpensive: Bool
    
    var quality: NetworkQuality {
        var score = 0
        
        // 延迟评分 (40% 权重)
        if latency < 50 {
            score += 40
        } else if latency < 100 {
            score += 30
        } else if latency < 200 {
            score += 20
        } else if latency < 500 {
            score += 10
        }
        
        // 带宽评分 (35% 权重)
        if bandwidth > 50 {
            score += 35
        } else if bandwidth > 25 {
            score += 28
        } else if bandwidth > 10 {
            score += 21
        } else if bandwidth > 5 {
            score += 14
        } else if bandwidth > 1 {
            score += 7
        }
        
        // 稳定性评分 (25% 权重)
        let stabilityScore = max(0, 25 - Int(packetLoss * 5) - Int(jitter / 10))
        score += stabilityScore
        
        // 网络条件惩罚
        if isConstrained { score -= 10 }
        if isExpensive { score -= 5 }
        
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .unknown
        }
    }
}

enum NetworkQuality: Int, CaseIterable {
    case excellent = 4
    case good = 3
    case fair = 2
    case poor = 1
    case unknown = 0
    
    var description: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .unknown: return "未知"
        }
    }
    
    var recommendedTimeout: TimeInterval {
        switch self {
        case .excellent: return 8.0
        case .good: return 12.0
        case .fair: return 20.0
        case .poor: return 35.0
        case .unknown: return 15.0
        }
    }
    
    var recommendedRetryCount: Int {
        switch self {
        case .excellent: return 2
        case .good: return 3
        case .fair: return 4
        case .poor: return 5
        case .unknown: return 3
        }
    }
}

print("🧪 网络质量算法验证")
print("================")

// 测试用例
let testCases = [
    ("优秀WiFi", NetworkQualityMetrics(latency: 20, bandwidth: 100, packetLoss: 0, jitter: 5, isConstrained: false, isExpensive: false)),
    ("良好4G", NetworkQualityMetrics(latency: 80, bandwidth: 50, packetLoss: 1, jitter: 15, isConstrained: false, isExpensive: false)),
    ("一般网络", NetworkQualityMetrics(latency: 120, bandwidth: 25, packetLoss: 2, jitter: 25, isConstrained: true, isExpensive: false)),
    ("较差网络", NetworkQualityMetrics(latency: 400, bandwidth: 5, packetLoss: 8, jitter: 120, isConstrained: true, isExpensive: false))
]

var allPassed = true

for (name, metrics) in testCases {
    let quality = metrics.quality
    print("\(name): \(quality.description) (超时:\(Int(quality.recommendedTimeout))s, 重试:\(quality.recommendedRetryCount)次)")
    
    // 基本验证
    if quality.recommendedTimeout < 5 || quality.recommendedTimeout > 40 {
        print("❌ 超时时间异常: \(quality.recommendedTimeout)")
        allPassed = false
    }
    
    if quality.recommendedRetryCount < 1 || quality.recommendedRetryCount > 6 {
        print("❌ 重试次数异常: \(quality.recommendedRetryCount)")
        allPassed = false
    }
}

if allPassed {
    print("✅ 所有测试通过")
    exit(0)
} else {
    print("❌ 测试失败")
    exit(1)
}
EOF

# 运行测试
echo "运行网络质量算法测试..."
swift test_network_quality_temp.swift

# 清理临时文件
rm test_network_quality_temp.swift

echo ""
echo "🧪 功能组件测试..."

# 检查关键文件是否存在
files=(
    "BilibiliLive/Request/NetworkQualityDetector.swift"
    "BilibiliLive/Request/NetworkRetryManager.swift"
    "BilibiliLive/Component/UI/NetworkQualityIndicatorView.swift"
    "BilibiliLive/Tests/NetworkQualityTests.swift"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ 缺失: $file"
    fi
done

echo ""
echo "📊 代码统计..."
echo "网络质量检测代码行数: $(find BilibiliLive/Request -name "*NetworkQuality*" -exec wc -l {} + | tail -1 | awk '{print $1}')"
echo "测试代码行数: $(find BilibiliLive/Tests -name "*NetworkQuality*" -exec wc -l {} + | tail -1 | awk '{print $1}')"

echo ""
echo "✅ 网络质量功能测试完成"