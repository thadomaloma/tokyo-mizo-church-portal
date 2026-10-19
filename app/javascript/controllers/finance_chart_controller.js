import { Controller } from "@hotwired/stimulus"
import "Chart.bundle"

// Finance charts drawn with Chart.js, styled to the app's design system and
// the dataviz rules: thin marks, hairline grid, text in ink (never the
// series colour), one shared tooltip with the value first, a crosshair on
// line charts, and a direct label only at the end of each line.
//
// data-finance-chart-config-value = { type: "bar"|"line", labels: [...],
//   series: [{ label, color, values, area, order, endLabel }], endLabels: true|false }
// Lower `order` draws on top; `endLabel: false` skips a context series.
const INK = "#191a2e"
const MUTED = "#6b6d8a"
const GRID = "#ededf5"
const SURFACE = "#ffffff"
const FONT = "Inter, ui-sans-serif, system-ui, sans-serif"

const yen = (value) => `¥${Math.round(value).toLocaleString("en-US")}`
const compactYen = (value) => {
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `¥${(value / 1_000_000).toFixed(abs >= 10_000_000 ? 0 : 1)}M`
  if (abs >= 1_000) return `¥${Math.round(value / 1_000)}k`
  return `¥${value}`
}

const hexToRgba = (hex, alpha) => {
  const value = parseInt(hex.replace("#", ""), 16)
  return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${alpha})`
}

// Vertical hairline that follows the hovered X on line charts.
const crosshair = {
  id: "financeCrosshair",
  afterDatasetsDraw(chart) {
    const active = chart.tooltip?.getActiveElements?.() || []
    if (chart.config.type !== "line" || active.length === 0) return

    const { ctx, chartArea } = chart
    const x = active[0].element.x
    ctx.save()
    ctx.strokeStyle = "#c4c5d8"
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(x, chartArea.top)
    ctx.lineTo(x, chartArea.bottom)
    ctx.stroke()
    ctx.restore()
  }
}

// Value label at the last point of each line, in ink, never series colour.
const endLabels = {
  id: "financeEndLabels",
  afterDatasetsDraw(chart, _args, options) {
    if (!options.enabled) return

    const { ctx } = chart
    ctx.save()
    ctx.font = `600 12px ${FONT}`
    ctx.fillStyle = INK
    ctx.textBaseline = "middle"

    chart.data.datasets.forEach((dataset, index) => {
      const meta = chart.getDatasetMeta(index)
      if (meta.hidden || dataset.endLabel === false) return

      const lastIndex = dataset.data.findLastIndex((value) => value !== null && value !== undefined)
      if (lastIndex < 0) return

      const point = meta.data[lastIndex]
      const text = yen(dataset.data[lastIndex])
      const width = ctx.measureText(text).width
      const roomRight = point.x + 8 + width <= chart.chartArea.right
      // Beside the last point when there is room, otherwise just above it;
      // a surface-coloured halo keeps it readable over other lines.
      const x = roomRight ? point.x + 8 : Math.min(point.x - width / 2, chart.chartArea.right - width)
      const y = roomRight ? point.y : point.y - 14
      ctx.lineWidth = 4
      ctx.strokeStyle = SURFACE
      ctx.strokeText(text, x, y)
      ctx.fillText(text, x, y)
    })
    ctx.restore()
  }
}

export default class extends Controller {
  static values = { config: Object }
  static targets = ["canvas"]

  connect() {
    if (!window.Chart) return

    this.chart = new window.Chart(this.canvasTarget, this.buildConfig())
  }

  disconnect() {
    this.chart?.destroy()
  }

  buildConfig() {
    const { type, labels, series, endLabels: showEndLabels } = this.configValue
    const isLine = type === "line"

    return {
      type,
      data: {
        labels,
        datasets: series.map((item) => this.dataset(item, isLine))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 250 },
        layout: { padding: { right: showEndLabels ? 72 : 4, top: 8 } },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          financeEndLabels: { enabled: Boolean(showEndLabels) },
          tooltip: {
            backgroundColor: SURFACE,
            borderColor: "#e7e7f1",
            borderWidth: 1,
            titleColor: MUTED,
            bodyColor: INK,
            titleFont: { family: FONT, size: 12, weight: "500" },
            bodyFont: { family: FONT, size: 13, weight: "600" },
            padding: 12,
            boxWidth: 12,
            boxHeight: 2,
            boxPadding: 6,
            usePointStyle: false,
            filter: (item) => item.raw !== null && item.raw !== undefined,
            callbacks: {
              title: (items) => (this.configValue.tooltipTitlePrefix || "") + (items[0]?.label ?? ""),
              label: (item) => `${yen(item.raw)}  ${item.dataset.label}`,
              labelColor: (item) => ({ borderColor: item.dataset.borderColor, backgroundColor: item.dataset.borderColor, borderWidth: 0 })
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            border: { color: "#d3d4e4" },
            ticks: {
              color: MUTED,
              font: { family: FONT, size: 12 },
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: isLine ? 8 : 12
            }
          },
          y: {
            beginAtZero: true,
            grid: { color: GRID, lineWidth: 1, drawTicks: false },
            border: { display: false },
            ticks: { color: MUTED, font: { family: FONT, size: 12 }, padding: 8, maxTicksLimit: 5, callback: compactYen }
          }
        }
      },
      plugins: [ crosshair, endLabels ]
    }
  }

  dataset(item, isLine) {
    if (isLine) {
      return {
        label: item.label,
        data: item.values,
        order: item.order ?? 0,
        endLabel: item.endLabel !== false,
        borderColor: item.color,
        backgroundColor: item.area ? hexToRgba(item.color, 0.1) : item.color,
        fill: item.area ? "origin" : false,
        borderWidth: 2,
        borderCapStyle: "round",
        borderJoinStyle: "round",
        tension: 0,
        spanGaps: false,
        pointRadius: 0,
        pointHoverRadius: 5,
        pointHoverBorderWidth: 2,
        pointHoverBorderColor: SURFACE,
        pointHoverBackgroundColor: item.color
      }
    }

    return {
      label: item.label,
      data: item.values,
      backgroundColor: item.color,
      hoverBackgroundColor: hexToRgba(item.color, 0.8),
      borderWidth: 0,
      borderRadius: { topLeft: 4, topRight: 4 },
      borderSkipped: "start",
      maxBarThickness: 24,
      categoryPercentage: 0.6,
      barPercentage: 0.92
    }
  }
}
