import sys

import sympy as sp

# Windows 默认 GBK 控制台无法输出 ∫ 等 Unicode 数学符号
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

from sympy.integrals.manualintegrate import integral_steps
from sympy.integrals.manualintegrate import (
    AddRule,
    AlternativeRule,
    AtomicRule,
    ConstantTimesRule,
    CyclicPartsRule,
    DontKnowRule,
    PartsRule,
    RewriteRule,
    URule,
)
from sympy.solvers.solveset import linear_eq_to_matrix
from sympy.stats import Normal, cdf, density

# 初始化终端美化打印
sp.init_printing(use_unicode=True)


def print_section(title):
    print(f"\n{'=' * 20} {title} {'=' * 20}")


def explain_integral_steps(rule, indent=0, depth=0, max_depth=64):
    """根据 SymPy manualintegrate 返回的规则树，自动打印推导步骤。"""
    if depth > max_depth:
        return
    pad = " " * indent
    var = rule.variable

    if isinstance(rule, PartsRule):
        v = rule.v_step.eval()
        # CyclicPartsRule 内部的 PartsRule 可能 integrand/variable/second_step 为空
        if var is None or rule.second_step is None:
            print(f"{pad}PartsRule：u = {rule.u}，dv = {rule.dv} → v = {v}")
            return
        du = sp.diff(rule.u, var)
        print(f"{pad}分部积分：∫({rule.integrand}) d{var}")
        print(f"{pad}  取 u = {rule.u}，dv = {rule.dv} → v = {v}，du = {du}")
        print(
            f"{pad}  ∫u·dv = u·v - ∫v·du = {rule.u}·({v}) - ∫({v})·({du}) d{var}"
        )
        explain_integral_steps(rule.second_step, indent + 2, depth + 1, max_depth)
        return

    if isinstance(rule, CyclicPartsRule):
        print(f"{pad}循环分部积分：∫({rule.integrand}) d{var}")
        for i, pr in enumerate(rule.parts_rules, 1):
            vp = pr.v_step.eval()
            print(f"{pad}  第 {i} 次：u = {pr.u}，dv = {pr.dv} → v = {vp}")
        print(f"{pad}  合并（规则 eval）= {rule.eval()}")
        return

    if isinstance(rule, ConstantTimesRule):
        print(
            f"{pad}常数提出：∫({rule.integrand}) d{var} = "
            f"{rule.constant} · ∫({rule.other}) d{var}"
        )
        explain_integral_steps(rule.substep, indent + 2, depth + 1, max_depth)
        return

    if isinstance(rule, AddRule):
        print(f"{pad}和式分项：∫({rule.integrand}) d{var}")
        for i, sub in enumerate(rule.substeps, 1):
            print(f"{pad}  —— 第 {i} 项 ——")
            explain_integral_steps(sub, indent + 4, depth + 1, max_depth)
        return

    if isinstance(rule, URule):
        print(f"{pad}换元：令 u = {rule.u_func}，对应 ∫(...) d{var}")
        explain_integral_steps(rule.substep, indent + 2, depth + 1, max_depth)
        return

    if isinstance(rule, RewriteRule):
        print(f"{pad}恒等改写：∫({rule.integrand}) d{var} → ∫({rule.rewritten}) d{var}")
        explain_integral_steps(rule.substep, indent + 2, depth + 1, max_depth)
        return

    if isinstance(rule, AlternativeRule):
        explain_integral_steps(rule.alternatives[0], indent, depth, max_depth)
        return

    if isinstance(rule, DontKnowRule):
        print(f"{pad}（无初等手算步骤）保留：∫({rule.integrand}) d{var}")
        return

    if isinstance(rule, AtomicRule):
        name = type(rule).__name__.replace("Rule", "")
        print(f"{pad}{name}：∫({rule.integrand}) d{var} = {rule.eval()}")
        return

    try:
        print(f"{pad}{type(rule).__name__}：∫({rule.integrand}) d{var} = {rule.eval()}")
    except Exception:
        print(f"{pad}{type(rule).__name__}：∫({rule.integrand}) d{var}")


def test_calculus():
    print_section("微积分：分部积分（由 integral_steps 自动生成步骤）")
    x = sp.Symbol("x")
    integrand = x**2 * sp.sin(x)
    print("不定积分：")
    sp.pprint(sp.Integral(integrand, x))
    steps = integral_steps(integrand, x)
    print("\n逐步推导（SymPy manualintegrate 规则树）：")
    explain_integral_steps(steps)
    antideriv = steps.eval()
    print("\n合并结果（+ 常数 C）：")
    sp.pprint(antideriv)
    print("+ C")


def test_linear_algebra():
    print_section("线性代数：克莱姆法则（矩阵与行列式自动计算）")
    x, y = sp.symbols("x y")
    var_list = [x, y]
    eqs = [sp.Eq(x + 2 * y, 5), sp.Eq(3 * x + 4 * y, 11)]
    print("方程组：")
    for eq in eqs:
        sp.pprint(eq)
    A, b = linear_eq_to_matrix(eqs, *var_list)
    print("\n矩阵形式 A·X = b：")
    print("A =")
    sp.pprint(A)
    print("b =")
    sp.pprint(b)
    D = A.det()
    print("\nD = det(A) =")
    sp.pprint(D)
    n = A.cols
    col_dets = []
    for j in range(n):
        Aj = A.copy()
        Aj[:, j] = b
        col_dets.append(Aj.det())
        print(f"\nD{j + 1} = det(第 {j + 1} 列换为 b 后的矩阵)")
        sp.pprint(Aj)
        sp.pprint(col_dets[-1])
    print("\n克莱姆法则：X_i = D_i / D")
    for j, sym in enumerate(var_list):
        val = sp.simplify(col_dets[j] / D)
        sp.pprint(sp.Eq(sym, val))


def test_probability():
    print_section("概率论：标准正态（stats 自动给出 PDF / CDF）")
    z = sp.Symbol("z")
    Z = Normal("Z", 0, 1)
    pdf_z = density(Z)(z)
    print("PDF φ(z) =")
    sp.pprint(pdf_z)
    prob = cdf(Z)(1) - cdf(Z)(-1)
    print("\nP(-1 < Z < 1) = Φ(1) - Φ(-1) =")
    sp.pprint(prob)
    print("\n等价积分形式：")
    sp.pprint(sp.Integral(pdf_z, (z, -1, 1)))
    print(f"\n数值：{float(prob.evalf()):.4f}")


if __name__ == "__main__":
    try:
        test_calculus()
        test_linear_algebra()
        test_probability()
    except Exception as e:
        print(f"发生错误: {e}")
