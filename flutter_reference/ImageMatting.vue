<template>
  <div class="image-matting-container">
    <!-- 标题部分 -->
    <div class="header" v-if="!originalImage.src">
      <h1 class="title">一键移除背景</h1>
      <p class="subtitle">3s一键抠图，免费去除图片背景，并替换成您选择的背景。</p>
    </div>

    <div class="content-wrapper">
      <!-- 左侧示例区域 -->
      <div class="examples-section" v-if="showVideoPlaceholder">
        <div class="video-placeholder">
          <video src="@/assets/展示视频.mp4" autoplay loop muted style="max-width: 400px; border-radius: 15px;"></video>
        </div>
      </div>

      <!-- 右侧处理区域 -->
      <div class="processing-section">
        <!-- 上传区域 -->
        <div class="upload-area" v-if="!originalImage.src" @dragover.prevent="onDragOver"
          @dragenter.prevent="onDragEnter" @dragleave.prevent="onDragLeave" @drop.prevent="onDrop">
          <div class="upload-content">
            <div class="upload-icon">
              <img src="@/assets/图像上传.png" alt="Upload">
            </div>
            <div class="context-describe">
              <p>粘贴图片、网址，或拖拽图片至此。</p>
              <p>支持批量处理20张图片。</p>
            </div>
            <div class="upload-buttons">
              <button class="btn upload-btn" @click="triggerFileUpload">
                <font-awesome-icon :icon="['fas', 'cloud-arrow-up']" class="mr-2" />上传图片
              </button>
              <button class="btn batch-upload-btn" @click="triggerBatchUpload">
                <font-awesome-icon :icon="['fas', 'folder-open']" class="mr-2" />批量上传
              </button>
            </div>
          </div>
          <input type="file" ref="fileInput" accept="image/*" style="display: none" @change="handleFileSelected" />
          <input type="file" ref="batchInput" accept="image/*" multiple style="display: none"
            @change="handleBatchSelected" />
        </div>

        <!-- 进度条 -->
        <div class="progress-bar" v-if="imageQueue.length > 0 && isProcessing">
          <div class="progress" :style="{ width: displayProgress + '%' }">
            <span class="progress-text">{{ displayProgressPercentage }}% ({{ currentBatchIndex }}/{{ imageQueue.length
              }})</span>
          </div>
        </div>

        <!-- 预览图队列 -->
        <div class="preview-queue" v-if="imageQueue && imageQueue.length > 0">
          <div class="preview-item" v-for="(item, index) in imageQueue" :key="index"
            :class="{ active: currentImageIndex === index, processing: item.isProcessing, completed: item.isCompleted }"
            @click="switchImage(index)">
            <img :src="item.previewSrc" alt="Preview" />
            <div class="status-overlay" v-if="item.isProcessing">
              <div class="spinner"></div>
            </div>
          </div>
        </div>

        <!-- 处理区域 -->
        <div class="image-processing-area" v-if="originalImage.src">
          <div class="tabs">
            <div class="tab" :class="{ active: activeTab === 'result' }" @click="activeTab = 'result'">
              已消除背景
            </div>
            <div class="tab" :class="{ active: activeTab === 'original' }" @click="activeTab = 'original'">
              原始图片
            </div>
          </div>

          <div class="image-display-area">
            <!-- 结果图显示区域 -->
            <div class="image-canvas-wrapper" v-show="activeTab === 'result'">
              <div class="transparent-bg checkerboard">
                <!-- 底层Canvas，显示最终结果 -->
                <canvas ref="resultCanvas"></canvas>
                <div class="processing-overlay" v-if="isProcessing">
                  <div class="spinner"></div>
                  <p>处理中...</p>
                </div>
              </div>
            </div>

            <!-- 原始图显示区域 -->
            <div class="image-canvas-wrapper" v-show="activeTab === 'original'">
              <canvas ref="canvasOriginal"></canvas>
            </div>
          </div>


          <!-- 编辑工具栏 -->
          <div class="editing-tools">
            <div class="tool-section">
              <h3>编辑图片</h3>
            </div>

            <!-- 比例调整 -->
            <div class="ratio-section">
              <div class="ratio-options">
                <div class="ratio-option" v-for="(ratio, index) in ratioOptions" :key="index"
                  :class="{ active: selectedRatio === ratio.value }" @click="selectRatio(ratio.value)">
                  <div class="ratio-icon">
                    <!-- 第一个选项使用 image 图标 -->
                    <font-awesome-icon v-if="ratio.value === 'original'" icon="image" class="icon-24" />
                    <!-- 第二个选项使用 crop 图标 -->
                    <font-awesome-icon v-else-if="ratio.value === 'magic'" :icon="['fas', 'crop']" class="icon-24" />
                    <!-- 其他选项使用图片 -->
                    <img v-else :src="require(`@/assets/icons/${ratio.icon}`)" :alt="ratio.label" />
                  </div>
                  <span class="ratio-label">{{ ratio.label }}</span>
                </div>
              </div>
            </div>



            <!-- 模型切换 -->
            <div class="model-section" v-if="originalImage.src">
              <h3 class="model-label">抠图模型</h3>
              <ul class="model-options">
                <li v-for="model in modelOptions" :key="model.value" :class="{ active: selectedModel === model.value }"
                  @click="selectModel(model.value)" @mouseenter="(event) => onMouseEnter(model, event)"
                  @mousemove="onMouseMove" @mouseleave="onMouseLeave">
                  <span>{{ model.label }}</span>
                </li>
              </ul>

              <!-- 浮窗展示 -->
              <div class="model-tooltip" v-if="hoveredModel" :style="tooltipStyle">
                <div class="tooltip-content">
                  <h4>{{ hoveredModel.label }}</h4>
                  <video class="model-demo-video" :src="hoveredModel.demoMp4" autoplay loop muted playsinline></video>
                  <p class="model-description">{{ hoveredModel.description }}</p>
                </div>
              </div>
            </div>

            <div class="background-color-section" v-if="resultImage">
              <h3>背景颜色</h3>
              <div class="color-picker">
                <div class="color-option"
                  v-for="color in ['transparent', '#FFFFFF', '#000000', '#FF0000', '#00FF00', '#0000FF', '#FFFF00']"
                  :key="color" :class="{ active: selectedBackgroundColor === color }"
                  :style="{ backgroundColor: color === 'transparent' ? 'transparent' : color }"
                  @click="applyBackgroundColor(color)">
                </div>
                <div class="custom-color-wheel" :class="{ active: isCustomColorActive }">
                  <input type="color" v-model="customBackgroundColor"
                    @change="applyBackgroundColor(customBackgroundColor)" title="自定义颜色" />
                </div>
              </div>
            </div>


            <!-- 下载区域 -->
            <div class="download-section">
              <div class="download-mode-toggle">
                <div class="toggle-slider"
                  :style="{ transform: `translateX(${downloadMode === 'all' ? '96px' : '0px'})` }"></div>
                <button :class="{ active: downloadMode === 'single' }" @click="downloadMode = 'single'">
                  单张下载
                </button>
                <button :class="{ active: downloadMode === 'all' }" @click="downloadMode = 'all'">
                  全部下载
                </button>
              </div>
              <button class="btn download-btn" @click="downloadImage"
                :disabled="!resultImage && downloadMode === 'single'">
                <font-awesome-icon :icon="['fas', 'download']" class="mr-2" />
                {{ downloadMode === 'single' ? '下载当前图片' : '下载所有图片' }}
              </button>
              <button class="btn upload-again-btn" @click="resetImage">
                <font-awesome-icon :icon="['fas', 'rotate-right']" class="mr-2" /> 再次上传
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>


  </div>
</template>

<script>
  import axios from 'axios';
  import { ElNotification, ElMessageBox } from 'element-plus';
  import pica from 'pica';
  import emitter from '@/utils/eventBus';

  export default {
    name: 'ImageMatting',
    data() {
      return {
        activeTab: 'result',
        originalImage: {
          src: '',
          width: 0,
          height: 0
        },
        resultImage: null,
        isMobile: false,        // 是否为移动设备
        downloadMode: 'single', // 'single' 表示单张下载，'all' 表示全部下载
        cropBoundaries: { minX: 0, maxX: 0, minY: 0, maxY: 0 }, // 保存裁剪边界，用于切换展示原图（仅在裁剪至边缘模式）
        showVideoPlaceholder: true, // 初始状态为显示
        initialResultImage: null, // 添加初始结果图像
        isProcessing: false,
        hoveredModel: null,
        imageQueue: [], // 确保初始化为数组
        selectedModel: 'high_precision',
        modelOptions: [
          {
            value: 'general',
            label: '通用抠图',
            description: '适用于大多数场景，包括动漫图片和照片，能快速准确地分离前景和背景。适用于4K及以下图像。单次下载扣除1点。',
            demoMp4: require('@/assets/rmbg-demo.mp4')
          },
          {
            value: 'high_precision',
            label: '高精度抠图',
            description: '专为需要精细边缘处理的图像设计，相较与通用会在边缘部分保留更多细节，更加注重主体。适用于4K及以上图像。单次下载扣除2点。',
            demoMp4: require('@/assets/high_precision.mp4')
          },
          {
            value: 'transparent_matting',
            label: '透明抠图',
            description: '特别擅长处理透明物体，玻璃材质或亚克力材质主体，生成完美的透明背景。单次下载扣除1点。',
            demoMp4: require('@/assets/transparent-matting-demo.mp4')
          }
        ],
        selectedRatio: 'original',
        progressPercentage: 0, // 进度百分比
        displayProgress: 0, // 添加 displayProgress
        userModifications: null,
        selectedBackgroundColor: 'transparent',
        customBackgroundColor: '#FFFFFF',
        batchQueue: [], // 批量处理队列
        currentBatchIndex: -1, // 当前处理的图片索引
        currentImageIndex: -1, // 当前显示的图片索引
        processingCanvas: null,
        ratioOptions: [
          { label: '原尺寸', value: 'original' },
          { label: '裁剪至边缘', value: 'magic' },
          { label: '1:1', value: '1:1', icon: '1-1.png' },
          { label: '2:3', value: '2:3', icon: '2-3.png' },
          { label: '3:4', value: '3:4', icon: '3-4.png' },
          { label: '4:3', value: '4:3', icon: '4-3.png' },
          { label: '9:16', value: '9:16', icon: '9_16.png' },
          { label: '16:9', value: '16:9', icon: '16-9.png' },
          { label: '21:9', value: '21:9', icon: '21-9.png' }
        ]
      };
    },
    computed: {
      // 更改模板中使用的值为动画后的值
      displayProgressPercentage() {
        return Math.round(this.displayProgress);
      }
    },
    watch: {
      // 监听实际进度百分比的变化，激活动画
      progressPercentage(newVal) {
        this.updateProgressWithAnimation(newVal);
      },
      activeTab: {
        handler() {
          this.$nextTick(() => {
            // 确保DOM已更新后再调整画布
            this.resizeCanvas();
          });
        },
        immediate: true
      }
    },
    mounted() {
      window.addEventListener('resize', this.resizeCanvas);
      this.processingCanvas = document.createElement('canvas');

      // 检测移动设备
      this.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ||
        (navigator.maxTouchPoints && navigator.maxTouchPoints > 0) ||
        window.matchMedia('(hover: none) and (pointer: coarse)').matches;

      try {
        this.picaInstance = pica();
        console.log('picaInstance 初始化成功:', this.picaInstance);
      } catch (error) {
        console.error('pica 初始化失败:', error);
        this.picaInstance = null;
      }
    },
    beforeUnmount() {
      window.removeEventListener('resize', this.resizeCanvas);
      this.currentBatchIndex = -1; // 停止批量处理
    },
    methods: {










      renderResultCanvas() {
        const resultCanvas = this.$refs.resultCanvas;
        if (!resultCanvas || !this.resultImage) return;

        const img = new Image();
        img.onload = () => {
          // 设置Canvas的尺寸为当前结果图的尺寸
          resultCanvas.width = this.resultImage.width;
          resultCanvas.height = this.resultImage.height;

          // 绘制结果图
          const ctx = resultCanvas.getContext('2d');
          ctx.clearRect(0, 0, resultCanvas.width, resultCanvas.height);
          ctx.drawImage(img, 0, 0);
        };
        img.src = this.resultImage.src;
      },





      // 模型切换展示部分
      onMouseEnter(model, event) {
        this.hoveredModel = model;
        this.updateTooltipPosition(event);
      },
      onMouseMove(event) {
        if (this.hoveredModel) {
          this.updateTooltipPosition(event);
        }
      },
      onMouseLeave() {
        this.hoveredModel = null;
      },
      updateTooltipPosition(event) {
        // Calculate position to avoid going off screen
        const padding = 15;
        const tooltipWidth = 320;
        const tooltipHeight = 300; // Approximate height

        // Get viewport dimensions
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // Initial position (cursor position)
        let left = event.clientX + padding;
        let top = event.clientY + padding;

        // Adjust if would go off right edge
        if (left + tooltipWidth > viewportWidth) {
          left = event.clientX - tooltipWidth - padding;
        }

        // Adjust if would go off bottom edge
        if (top + tooltipHeight > viewportHeight) {
          top = event.clientY - tooltipHeight - padding;
        }

        // Apply position
        this.tooltipStyle = {
          top: `${top}px`,
          left: `${left}px`
        };
      },
      // 生成预览图
      generatePreview(file) {
        return new Promise((resolve) => {
          const reader = new FileReader();
          reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
              const canvas = document.createElement('canvas');
              const ctx = canvas.getContext('2d');
              const maxSize = 150; //预览图大小
              let width = img.width;
              let height = img.height;

              if (width > height) {
                height = (maxSize * height) / width;
                width = maxSize;
              } else {
                width = (maxSize * width) / height;
                height = maxSize;
              }

              canvas.width = width;
              canvas.height = height;
              ctx.drawImage(img, 0, 0, width, height);
              resolve(canvas.toDataURL('image/jpeg', 0.7));
            };
            img.src = e.target.result;
          };
          reader.readAsDataURL(file);
        });
      },

      // 拖拽上传处理
      async onDrop(event) {
        event.preventDefault();
        this.dragActive = false;

        const files = event.dataTransfer.files;
        if (files.length > 0) {
          const validFiles = Array.from(files).filter(file => file.type.startsWith('image/'));
          if (validFiles.length === 0) {
            ElNotification({
              type: 'warning',
              title: '警告',
              message: '请上传图片文件'
            });
            return;
          }

          // 如果拖拽了多张图片，检查登录状态
          if (validFiles.length > 1) {
            const isLoggedIn = await this.checkUserInfo();
            if (!isLoggedIn || !this.userInfo) {
              ElNotification({
                type: 'warning',
                title: '请先登录',
                message: '批量处理功能需要登录后才能使用'
              });
              return;
            }

            // 多张图片处理逻辑
            if (validFiles.length > 30) {
              ElNotification({
                type: 'warning',
                title: '警告',
                message: '最多支持批量处理30张图片'
              });
              validFiles.splice(30);
            }

            if (!Array.isArray(this.imageQueue)) {
              console.warn('imageQueue 不是数组，正在重新初始化');
              this.imageQueue = [];
            }

            for (const file of validFiles) {
              const previewSrc = await this.generatePreview(file);
              this.imageQueue.push({
                file,
                previewSrc,
                original: null,
                result: null,
                isProcessing: false,
                isCompleted: false
              });
            }

            if (this.currentBatchIndex === -1) {
              this.currentBatchIndex = 0;
              this.currentImageIndex = 0;
              this.processNextImage();
            }
          } else {
            // 单张图片处理逻辑 - 不需要登录
            const file = validFiles[0];
            // 将单张图片添加到队列中，保持与 handleFileSelected 方法一致的逻辑
            this.generatePreview(file).then(previewSrc => {
              this.imageQueue = [{
                file,
                previewSrc,
                original: null,
                result: null,
                isProcessing: false,
                isCompleted: false
              }];
              this.currentBatchIndex = 0;
              this.currentImageIndex = 0;
              this.processNextImage();
            });
          }
        }
      },

      // 处理下一张图片
      async processNextImage() {
        if (this.currentBatchIndex >= this.imageQueue.length) {
          this.progressPercentage = 100;
          this.currentBatchIndex = -1; // 处理完成，重置索引
          return; // 所有图片处理完成
        }

        const item = this.imageQueue[this.currentBatchIndex];
        if (!item || !item.file) {
          console.error('无效的 item 或 file:', item);
          this.currentBatchIndex++;
          this.processNextImage();
          return;
        }

        item.isProcessing = true;
        this.isProcessing = true;
        this.updateProgress();

        // 加载图片
        const reader = new FileReader();
        reader.onload = async (e) => {
          const img = new Image();
          img.onload = async () => {
            item.original = {
              src: img.src,
              width: img.width,
              height: img.height
            };

            if (this.currentImageIndex === this.currentBatchIndex) {
              this.originalImage = { ...item.original };
              this.resultImage = null;
              this.initialResultImage = null;
              this.userModifications = null;
              this.showVideoPlaceholder = false;
              await this.$nextTick();
              this.resizeCanvas();
            }

            await this.processImage(item);

            item.isProcessing = false;
            item.isCompleted = true;
            this.isProcessing = false;

            this.updateProgress();

            this.currentBatchIndex++;
            this.processNextImage();
          };
          img.src = e.target.result;
        };
        reader.readAsDataURL(item.file);
      },

      // 更新进度条
      updateProgress() {
        if (this.imageQueue.length > 0) {
          const newPercentage = Math.round((this.currentBatchIndex / this.imageQueue.length) * 100);
          this.updateProgressWithAnimation(newPercentage);
        } else {
          this.updateProgressWithAnimation(0);
        }
      },

      updateProgressWithAnimation(newPercentage) {
        const startPercentage = this.displayProgress;
        const changeInPercentage = newPercentage - startPercentage;
        const duration = 1000; // 1秒钟的动画时长
        const startTime = performance.now();

        const animateProgress = (currentTime) => {
          const elapsedTime = currentTime - startTime;

          if (elapsedTime < duration) {
            // 使用缓动函数计算当前进度
            const progress = elapsedTime / duration;
            const easeProgress = this.easeOutQuad(progress);
            this.displayProgress = startPercentage + changeInPercentage * easeProgress;
            requestAnimationFrame(animateProgress);
          } else {
            this.displayProgress = newPercentage;
          }
        };

        requestAnimationFrame(animateProgress);
      },

      // 缓动函数 - 使动画更自然
      easeOutQuad(t) {
        return t * (2 - t);
      },
      // 切换显示图片
      // 请用这个版本替换掉您现有的 switchImage 方法
      switchImage(index) {
        // 如果点击的是当前已显示的图片，则不执行任何操作
        if (this.currentImageIndex === index) {
          return;
        }

        this.currentImageIndex = index;
        const item = this.imageQueue[index];

        // 确保数据源是有效的
        if (!item || !item.original) {
          console.error('切换失败：选择的图片项无效或没有原始数据。');
          return;
        }

        // 1. 更新基础数据状态
        this.originalImage = { ...item.original };
        this.resultImage = item.result ? { ...item.result } : null;
        this.initialResultImage = item.initialResult ? { ...item.initialResult } : null;

        // 切换时，重置比例和背景色选项到默认值
        this.selectedRatio = 'original';
        this.selectedBackgroundColor = 'transparent';

        // 【关键步骤】
        // 使用 $nextTick 确保DOM更新后（比如 v-if/v-show切换），Canvas元素是可用的
        this.$nextTick(() => {
          if (this.activeTab === 'result') {
            // 如果结果图存在，就调用渲染方法重绘 Canvas
            if (this.resultImage) {
              this.renderResultCanvas();
            } else {
              // 如果结果图还未生成（例如还在处理中），可以清空Canvas
              const resultCanvas = this.$refs.resultCanvas;
              if (resultCanvas) {
                resultCanvas.getContext('2d').clearRect(0, 0, resultCanvas.width, resultCanvas.height);
              }
            }
          }

          // 不论在哪个tab，尺寸都需要重新计算
          this.resizeCanvas();
        });
      },



      // 重置
      resetImage() {
        this.originalImage = { src: '', width: 0, height: 0 };
        this.resultImage = null;
        this.initialResultImage = null;
        this.activeTab = 'result';
        this.userModifications = null;
        this.currentBatchIndex = -1;
        this.currentImageIndex = -1;
        this.imageQueue = [];
        this.showVideoPlaceholder = true;
        if (this.$refs.fileInput) this.$refs.fileInput.value = '';
        if (this.$refs.batchInput) this.$refs.batchInput.value = '';

        // 添加平滑滚动到页面顶部的动画效果
        window.scrollTo({
          top: 0,
          behavior: 'smooth' // 使用平滑滚动而不是瞬间跳转
        });
      },

      // 切换模型
      selectModel(model) {
        if (this.selectedModel === model) {
          return; // 如果选择的是当前模型，直接返回
        }

        // 使用 ElMessageBox.confirm 弹出确认框
        ElMessageBox.confirm('是否更换模型并重新处理所有图片？', '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        }).then(() => {
          // 用户点击"确定"
          this.selectedModel = model;

          // 重置处理状态
          this.currentBatchIndex = 0;
          this.isProcessing = false;
          this.progressPercentage = 0;

          // 重置 imageQueue 中所有图片的状态
          this.imageQueue.forEach(item => {
            item.isProcessing = false;
            item.isCompleted = false;
            item.result = null;
            item.initialResult = null;
          });

          // 重新开始处理
          if (this.imageQueue.length > 0) {
            this.currentImageIndex = 0;
            this.originalImage = { ...this.imageQueue[0].original };
            this.resultImage = null;
            this.initialResultImage = null;
            this.userModifications = null;
            this.$nextTick(() => {
              this.resizeCanvas();
              this.processNextImage(); // 从头开始处理
            });
          } else {
            console.warn('selectModel: 没有图片需要处理');
          }
        }).catch(() => {
          // 用户点击"取消"或关闭弹窗
          console.log('用户取消了模型切换');
        });
      },
      resetToOriginalSize() {
        if (!this.originalImage.src) return;
        // 重置为原尺寸
        this.selectedRatio = 'original';
        // 重新处理图像
        this.processImage();
      },

      applyBackgroundColor(color) {
        if (!this.initialResultImage || !this.originalImage) return;
        this.selectedBackgroundColor = color;

        // 创建一个新的临时画布
        const tempCanvas = document.createElement('canvas');
        const ctx = tempCanvas.getContext('2d');

        // 根据 selectedRatio 选择合适的宽高
        let width, height;

        if (this.selectedRatio === 'magic') {
          // 对于 magic 模式，先计算裁剪边界
          const cropResult = this.calculateCropBoundaries();
          if (cropResult) {
            width = cropResult.cropWidth;
            height = cropResult.cropHeight;
          } else {
            // 如果裁剪失败，使用原始尺寸
            width = this.initialResultImage.width;
            height = this.initialResultImage.height;
          }
        } else {
          width = this.initialResultImage.width;
          height = this.initialResultImage.height;
        }

        tempCanvas.width = width;
        tempCanvas.height = height;

        // 清除画布，确保没有残留
        ctx.clearRect(0, 0, width, height);

        // 如果不是透明背景，先绘制背景色
        if (color !== 'transparent') {
          ctx.fillStyle = color;
          ctx.fillRect(0, 0, width, height);
        }

        // 加载 initialResultImage（透明结果图）
        const img = new Image();
        img.crossOrigin = "Anonymous";

        img.onload = () => {
          if (this.selectedRatio === 'magic') {
            // 使用裁剪后的图像数据
            const cropResult = this.calculateCropBoundaries();
            if (cropResult) {
              // 绘制裁剪后的图像
              ctx.drawImage(
                img,
                cropResult.minX, cropResult.minY, cropResult.cropWidth, cropResult.cropHeight,
                0, 0, cropResult.cropWidth, cropResult.cropHeight
              );
            } else {
              // 裁剪失败，居中绘制原图
              const offsetX = Math.floor((width - this.initialResultImage.width) / 2);
              const offsetY = Math.floor((height - this.initialResultImage.height) / 2);
              ctx.drawImage(img, offsetX, offsetY);
            }
          } else {
            // 其他模式，居中绘制
            const offsetX = Math.floor((width - this.initialResultImage.width) / 2);
            const offsetY = Math.floor((height - this.initialResultImage.height) / 2);
            ctx.drawImage(img, offsetX, offsetY);
          }

          // 更新 resultImage
          const resultImg = new Image();
          resultImg.onload = () => {
            this.resultImage = {
              src: resultImg.src,
              width: tempCanvas.width,
              height: tempCanvas.height,
              originalSrc: this.initialResultImage.originalSrc || this.initialResultImage.src,
              hasAlphaChannel: true
            };

            // 重新渲染结果Canvas
            this.$nextTick(() => {
              this.renderResultCanvas();
              this.resizeCanvas();
            });
          };
          resultImg.src = tempCanvas.toDataURL('image/png');
        };

        img.src = this.initialResultImage.src;
      },

      triggerFileUpload() {
        this.$refs.fileInput.click();
      },
      triggerBatchUpload() {
        // 检查用户登录状态
        this.checkUserInfo().then(isLoggedIn => {
          if (!isLoggedIn || !this.userInfo) {
            ElNotification({
              type: 'warning',
              title: '请先登录',
              message: '批量处理功能需要登录后才能使用'
            });
            return;
          }
          this.$refs.batchInput.click();
        });
      },
      // 处理单张上传
      async handleFileSelected(event) {
        const file = event.target.files[0];
        if (file) {
          const previewSrc = await this.generatePreview(file);

          if (!Array.isArray(this.imageQueue)) {
            console.warn('imageQueue 不是数组，正在重新初始化');
            this.imageQueue = [];
          }

          this.imageQueue.push({
            file,
            previewSrc,
            original: null,
            result: null,
            isProcessing: false,
            isCompleted: false
          });

          if (this.currentBatchIndex === -1) {
            this.currentBatchIndex = 0;
            this.currentImageIndex = 0;
            this.processNextImage();
          }
        }
      },

      // 处理批量上传
      async handleBatchSelected(event) {
        // 首先检查用户登录状态
        const isLoggedIn = await this.checkUserInfo();
        if (!isLoggedIn || !this.userInfo) {
          ElNotification({
            type: 'warning',
            title: '请先登录',
            message: '批量处理功能需要登录后才能使用'
          });
          return;
        }

        const files = event.target.files;
        if (files.length > 0) {
          const validFiles = Array.from(files).filter(file => file.type.startsWith('image/'));
          if (validFiles.length === 0) {
            ElNotification({
              type: 'warning',
              title: '警告',
              message: '请上传图片文件'
            });
            return;
          }

          if (validFiles.length > 20) {
            ElNotification({
              type: 'warning',
              title: '警告',
              message: '最多支持批量处理20张图片'
            });
            validFiles.splice(20);
          }

          if (!Array.isArray(this.imageQueue)) {
            console.warn('imageQueue 不是数组，正在重新初始化');
            this.imageQueue = [];
          }

          for (const file of validFiles) {
            const previewSrc = await this.generatePreview(file);
            this.imageQueue.push({
              file,
              previewSrc,
              original: null,
              result: null,
              isProcessing: false,
              isCompleted: false
            });
          }

          if (this.currentBatchIndex === -1) {
            this.currentBatchIndex = 0;
            this.currentImageIndex = 0;
            this.processNextImage();
          }
        }
      },
      loadImage(file) {
        const reader = new FileReader();
        reader.onload = (e) => {
          const img = new Image();
          img.onload = () => {
            this.originalImage = {
              src: img.src,
              width: img.width,
              height: img.height
            };
            this.$nextTick(() => {
              this.showVideoPlaceholder = false; // 隐藏 video-placeholder
              this.resizeCanvas();
              // Give some time for the canvas to be ready
              setTimeout(() => {
                this.processImage();
              }, 100);
            });
          };
          img.src = e.target.result;
        };
        reader.readAsDataURL(file);
      },


      resizeCanvas() {
        // 目标：调整 resultCanvas 的显示大小（style），使其适应容器

        const resultCanvas = this.$refs.resultCanvas;
        const originalCanvas = this.$refs.canvasOriginal; // 原始图Canvas也需要处理

        // 容器
        const displayArea = this.$el.querySelector('.image-display-area');
        if (!displayArea) return;

        const maxWidth = displayArea.clientWidth;
        const maxHeight = window.innerHeight * 0.6;

        if (this.activeTab === 'result' && resultCanvas && this.resultImage) {
          // --- 处理结果图的Canvas ---
          const canvasWidth = this.resultImage.width;
          const canvasHeight = this.resultImage.height;
          const canvasRatio = canvasWidth / canvasHeight;

          let displayWidth = canvasWidth;
          let displayHeight = canvasHeight;

          // 根据容器大小计算显示尺寸
          if (displayWidth > maxWidth) {
            displayWidth = maxWidth;
            displayHeight = displayWidth / canvasRatio;
          }
          if (displayHeight > maxHeight) {
            displayHeight = maxHeight;
            displayWidth = displayHeight * canvasRatio;
          }

          // 应用样式到Canvas上
          resultCanvas.style.width = `${displayWidth}px`;
          resultCanvas.style.height = `${displayHeight}px`;

          // 同时调整外层容器的大小
          const wrapper = this.$el.querySelector('.transparent-bg.checkerboard');
          if (wrapper) {
            wrapper.style.width = `${displayWidth}px`;
            wrapper.style.height = `${displayHeight}px`;
          }

        } else if (this.activeTab === 'original' && originalCanvas && this.originalImage.src) {
          // --- 处理原始图的Canvas（这部分逻辑可以保持不变） ---
          const imgWidth = this.originalImage.width;
          const imgHeight = this.originalImage.height;
          const imgRatio = imgWidth / imgHeight;

          let displayWidth = imgWidth;
          let displayHeight = imgHeight;

          if (displayWidth > maxWidth) {
            displayWidth = maxWidth;
            displayHeight = displayWidth / imgRatio;
          }
          if (displayHeight > maxHeight) {
            displayHeight = maxHeight;
            displayWidth = displayHeight * imgRatio;
          }

          // 设置原始图Canvas的逻辑和显示尺寸
          originalCanvas.width = imgWidth;
          originalCanvas.height = imgHeight;
          originalCanvas.style.width = `${displayWidth}px`;
          originalCanvas.style.height = `${displayHeight}px`;

          const ctx = originalCanvas.getContext('2d');
          const img = new Image();
          img.onload = () => {
            ctx.clearRect(0, 0, imgWidth, imgHeight);
            ctx.drawImage(img, 0, 0, imgWidth, imgHeight);
          };
          img.src = this.originalImage.src;
        }
      },

      async processImage(item) {
        try {
          if (!item || !item.original) {
            console.error('item 或 item.original 未定义:', item);
            throw new Error('无效的图片数据');
          }

          const sourceCanvas = document.createElement('canvas');
          sourceCanvas.width = item.original.width;
          sourceCanvas.height = item.original.height;
          const sourceCtx = sourceCanvas.getContext('2d');
          const originalImageElement = new Image();
          originalImageElement.src = item.original.src;
          await new Promise(resolve => { originalImageElement.onload = resolve; });
          sourceCtx.drawImage(originalImageElement, 0, 0);

          if (!this.picaInstance || typeof this.picaInstance.resize !== 'function') {
            console.error('picaInstance 未正确初始化，正在重新初始化');
            this.picaInstance = pica();
          }

          // --- 准备上传数据 ---
          const maxDimension = Math.max(originalImageElement.width, originalImageElement.height);
          let blob;

          // 根据模型类型设置不同的最大尺寸
          let maxAllowedSize;
          if (this.selectedModel === 'high_precision') {
            maxAllowedSize = 2304; // 高精度抠图最大边长2304
          } else if (this.selectedModel === 'general') {
            maxAllowedSize = 1024; // 普通抠图最大边长1024
          } else if (this.selectedModel === 'transparent_matting') {
            maxAllowedSize = 512; // 透明抠图保持原有逻辑
          } else {
            maxAllowedSize = 1024; // 默认值
          }

          if (maxDimension > maxAllowedSize) {
            const targetCanvas = document.createElement('canvas');
            const scale = maxAllowedSize / maxDimension;
            targetCanvas.width = Math.floor(originalImageElement.width * scale);
            targetCanvas.height = Math.floor(originalImageElement.height * scale);

            await this.picaInstance.resize(sourceCanvas, targetCanvas, { quality: 3, alpha: true });
            blob = await new Promise(resolve => targetCanvas.toBlob(resolve, 'image/jpeg', 0.85));
          } else {
            blob = await new Promise(resolve => sourceCanvas.toBlob(resolve, 'image/jpeg', 0.85));
          }

          const formData = new FormData();
          formData.append('image', blob, 'image.jpg');
          formData.append('model_type', this.selectedModel);

          // 普通抠图和高精度抠图都使用同一个高精度接口
          const apiEndpoint =
            this.selectedModel === 'transparent_matting'
              ? 'https://creatinf.com/process_transparent_matting'
              : 'https://creatinf.com/process_high_precision'; // general和high_precision都用高精度接口

          // --- 获取后端返回的蒙版 ---
          const response = await axios.post(apiEndpoint, formData, {
            headers: { 'Content-Type': 'multipart/form-data' },
            responseType: 'json'
          });

          const maskImageFromAPI = new Image();
          maskImageFromAPI.src = 'data:image/png;base64,' + response.data.mask;
          await new Promise(resolve => { maskImageFromAPI.onload = resolve; });

          // --- 核心处理逻辑：应用蒙版 ---

          // 1. 将API返回的蒙版图像缩放到与原图一致的尺寸
          const tempMaskCanvas = document.createElement('canvas');
          tempMaskCanvas.width = item.original.width;
          tempMaskCanvas.height = item.original.height;
          const tempMaskCtx = tempMaskCanvas.getContext('2d');

          // 使用Pica库进行高质量缩放
          const tempMaskCanvasForResize = document.createElement('canvas'); // Pica需要源Canvas
          tempMaskCanvasForResize.width = maskImageFromAPI.width;
          tempMaskCanvasForResize.height = maskImageFromAPI.height;
          tempMaskCanvasForResize.getContext('2d').drawImage(maskImageFromAPI, 0, 0);
          await this.picaInstance.resize(tempMaskCanvasForResize, tempMaskCanvas, { quality: 3, alpha: true });

          // 2. 准备结果画布，绘制原图
          const resultCanvas = document.createElement('canvas');
          resultCanvas.width = item.original.width;
          resultCanvas.height = item.original.height;
          const resultCtx = resultCanvas.getContext('2d');
          resultCtx.drawImage(originalImageElement, 0, 0);

          // 3. 获取原图和最终蒙版的像素数据
          const imageData = resultCtx.getImageData(0, 0, resultCanvas.width, resultCanvas.height);
          const maskData = tempMaskCtx.getImageData(0, 0, tempMaskCanvas.width, tempMaskCanvas.height).data;

          // 4. 遍历像素，应用平滑蒙版
          for (let i = 0; i < imageData.data.length; i += 4) {
            // maskData是灰度图，其R, G, B值相等。我们取第一个（R）作为Alpha值。
            const alphaValue = maskData[i];
            // 直接将 0-255 的灰度值赋给结果图的 Alpha 通道，保留平滑边缘
            imageData.data[i + 3] = alphaValue;
          }

          // 5. 将修改后的像素数据放回结果画布
          resultCtx.putImageData(imageData, 0, 0);

          // --- 更新组件状态 ---
          const resultImgSrc = resultCanvas.toDataURL('image/png');

          // 更新当前处理项的结果
          item.result = {
            src: resultImgSrc,
            width: item.original.width,
            height: item.original.height,
            originalSrc: resultImgSrc, // 保存一份原始结果
            hasAlphaChannel: true
          };
          item.initialResult = { ...item.result };

          // 如果当前显示的是正在处理的图片，则立即更新UI
          if (this.currentImageIndex === this.currentBatchIndex) {
            this.resultImage = { ...item.result };
            this.initialResultImage = { ...item.initialResult };

            await this.$nextTick();

            // 调用渲染方法来设置结果Canvas
            this.renderResultCanvas();

            // 调整各种比例和尺寸
            this.adjustAspectRatio(() => {
              this.$nextTick(() => {
                // 注意：这里可能需要一个调整所有Canvas尺寸的方法
                this.resizeCanvas();
              });
            });
          }
        } catch (error) {
          console.error('处理图片失败:', error);
          ElNotification({
            type: 'error',
            title: '处理失败',
            message: error.response?.data?.error || '请重试'
          });
          if (item) {
            item.isProcessing = false;
            item.isCompleted = false;
          }
        } finally {
          item.isProcessing = false; // 确保处理状态被重置
          this.isProcessing = this.imageQueue.some(img => img.isProcessing);
        }
      },

      async processBatchItem(index) {
        // 批量处理逻辑
        const file = this.batchQueue[index];
        if (!file) return;

        // 加载图像
        await new Promise((resolve) => {
          const reader = new FileReader();
          reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
              this.originalImage = {
                src: img.src,
                width: img.width,
                height: img.height
              };
              this.resizeCanvas();
              resolve();
            };
            img.src = e.target.result;
          };
          reader.readAsDataURL(file);
        });

        // 处理图像
        await this.processImage();
      },
      async downloadImage() {
        try {
          // Force check login status
          const isLoggedIn = await this.checkUserInfo();

          if (!isLoggedIn || !this.userInfo) {
            ElNotification({
              type: 'warning',
              title: '请先登录',
              message: '下载功能需要登录后才能使用，如已经登录请刷新界面重试'
            });
            return;
          }

          if (this.downloadMode === 'single') {
            // 单张下载
            const resultCanvas = this.$refs.resultCanvas;
            if (!resultCanvas) { // 修改判断条件，检查canvas是否存在
              ElNotification({
                type: 'warning',
                title: '警告',
                message: '请先处理一张图片'
              });
              return;
            }

            // 获取图像数据
            const latestImageDataUrl = resultCanvas.toDataURL('image/png');

            // 检查下载配额
            const quotaResponse = await this.checkDownloadQuota();

            if (!quotaResponse.success) {
              ElNotification({
                type: 'error',
                title: '下载失败',
                message: quotaResponse.error || '配额不足，无法下载'
              });
              return;
            }

            // 更新用户配额信息
            if (quotaResponse.quotaInfo) {
              this.updateUserQuotaInfo(quotaResponse.quotaInfo);
            }

            // 执行下载
            this.triggerDownload(latestImageDataUrl, '扣图结果.png');

            ElNotification({
              type: 'success',
              title: '下载成功',
              message: quotaResponse.message || '图片已成功下载'
            });
            emitter.emit('refresh-user-info');
            console.log('Event "refresh-user-info" emitted.');

          } else {
            // 全部下载（串行）
            const completedImages = this.imageQueue.filter(item => item.isCompleted && item.result);
            if (!completedImages.length) {
              ElNotification({
                type: 'warning',
                title: '警告',
                message: '没有已处理的图片可下载'
              });
              return;
            }

            // 检查是否有足够的配额
            const totalImages = completedImages.length;
            if (this.userInfo.remaining_images < totalImages) {
              ElNotification({
                type: 'error',
                title: '配额不足',
                message: `您当前剩余配额为${this.userInfo.remaining_images}张，需要${totalImages}张，配额不足`
              });
              return;
            }

            this.isProcessing = true; // 显示处理中状态

            // 批量处理每张图片
            for (let i = 0; i < completedImages.length; i++) {
              const item = completedImages[i];
              const fileName = `image_${i + 1}.png`;

              // 检查下载配额
              const quotaResponse = await this.checkDownloadQuota();

              if (!quotaResponse.success) {
                ElNotification({
                  type: 'warning',
                  title: '部分下载失败',
                  message: `第${i + 1}张图片下载失败: ${quotaResponse.error || '配额不足'}`
                });
                continue; // 跳过这张图片，继续下载其他图片
              }

              // 更新用户配额信息
              if (quotaResponse.quotaInfo) {
                this.updateUserQuotaInfo(quotaResponse.quotaInfo);
              }

              // 下载图片
              await this.triggerDownloadWithDelay(item.result.src, fileName);
            }

            this.isProcessing = false;

            ElNotification({
              type: 'success',
              title: '批量下载完成',
              message: '所有图片已成功下载'
            });
            emitter.emit('refresh-user-info');
            console.log('Event "refresh-user-info" emitted after batch download.');
          }
        } catch (error) {
          console.error('Download process error:', error);
          ElNotification({
            type: 'error',
            title: '下载失败',
            message: error.response?.data?.error || error.message
          });
          this.isProcessing = false;
        }
      },

      // 检查下载配额
      async checkDownloadQuota() {
        try {
          const response = await axios.post('https://creatinf.com/check_download_quota', {
            modelType: this.selectedModel
          }, {
            withCredentials: true,
          });

          console.log('Quota check response:', response);

          return {
            success: response.data.success,
            error: response.data.error,
            message: response.data.message,
            quotaInfo: response.data.quotaInfo
          };
        } catch (error) {
          console.error('Error checking quota:', error);
          return {
            success: false,
            error: error.response?.data?.error || error.message
          };
        }
      },

      // 更新用户配额信息
      updateUserQuotaInfo(quotaInfo) {
        if (quotaInfo) {
          this.userInfo = {
            ...this.userInfo,
            daily_free_images: quotaInfo.daily_free_images,
            remaining_images: quotaInfo.remaining_images
          };

          // 更新本地存储
          localStorage.setItem('userInfo', JSON.stringify(this.userInfo));
        }
      },

      // 获取结果图像数据
      getResultImageData() {
        return this.resultImage?.src || '';
      },

      // 触发单张下载
      triggerDownload(src, fileName) {
        const link = document.createElement('a');
        link.download = fileName;
        link.href = src;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      },

      // 串行下载，添加延迟以避免浏览器限制
      triggerDownloadWithDelay(src, fileName) {
        return new Promise(resolve => {
          setTimeout(() => {
            this.triggerDownload(src, fileName);
            resolve();
          }, 500); // 每张下载间隔 500ms，避免浏览器同时触发过多下载
        });
      },

      // 检查用户信息
      async checkUserInfo() {
        try {
          // 检查缓存中是否有用户信息
          const cachedUserInfo = localStorage.getItem('userInfo');
          if (cachedUserInfo) {
            this.userInfo = JSON.parse(cachedUserInfo);
            return true;
          }

          // 如果没有缓存，则从服务器获取用户信息
          const response = await axios.get('https://creatinf.com/user_info', {
            withCredentials: true
          });

          if (response.data.success) {
            const userData = response.data.data || response.data.user;
            if (userData) {
              this.userInfo = userData;
              // 缓存用户信息
              localStorage.setItem('userInfo', JSON.stringify(userData));
              return true;
            }
          }

          this.userInfo = null;
          return false;
        } catch (error) {
          console.error('Error checking user info:', error);
          this.userInfo = null;
          return false;
        }
      },


      selectRatio(ratio) {
        this.selectedRatio = ratio;

        // 如果当前有背景色设置，需要重新应用以保持一致性
        if (this.selectedBackgroundColor !== 'transparent') {
          this.applyBackgroundColor(this.selectedBackgroundColor);
        } else {
          this.adjustAspectRatio();
        }
      },
      adjustAspectRatio(callback) {
        if (!this.initialResultImage) {
          console.warn('initialResultImage 不存在，无法调整比例');
          if (callback) callback();
          return;
        }

        const tempCanvas = document.createElement('canvas');
        const ctx = tempCanvas.getContext('2d');

        const loadImage = (src) => {
          return new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = "Anonymous";
            img.onload = () => resolve(img);
            img.onerror = () => reject(new Error(`无法加载图像: ${src}`));
            img.src = src;
          });
        };

        const processImage = async () => {
          let newWidth, newHeight;

          if (this.selectedRatio === 'original') {
            // 恢复到初始抠图结果
            this.resultImage = { ...this.initialResultImage };
            newWidth = this.resultImage.width;
            newHeight = this.resultImage.height;
            tempCanvas.width = newWidth;
            tempCanvas.height = newHeight;
            ctx.clearRect(0, 0, newWidth, newHeight);
            const img = await loadImage(this.resultImage.src);
            ctx.drawImage(img, 0, 0);

            // 重置裁剪边界
            this.cropBoundaries = { minX: 0, maxX: newWidth - 1, minY: 0, maxY: newHeight - 1 };
          } else if (this.selectedRatio === 'magic') {
            // 使用新的裁剪边界计算方法
            const cropResult = await this.calculateCropBoundaries();

            if (cropResult) {
              newWidth = cropResult.cropWidth;
              newHeight = cropResult.cropHeight;

              tempCanvas.width = newWidth;
              tempCanvas.height = newHeight;
              ctx.clearRect(0, 0, newWidth, newHeight);

              // 绘制背景色（如果不是透明）
              if (this.selectedBackgroundColor !== 'transparent') {
                ctx.fillStyle = this.selectedBackgroundColor;
                ctx.fillRect(0, 0, newWidth, newHeight);
              }

              // 绘制裁剪后的图像
              const img = await loadImage(this.initialResultImage.src);
              ctx.drawImage(
                img,
                cropResult.minX, cropResult.minY, newWidth, newHeight,
                0, 0, newWidth, newHeight
              );
            } else {
              // 裁剪失败，使用原始尺寸
              console.warn('裁剪失败，使用原始尺寸');
              this.resultImage = { ...this.initialResultImage };
              newWidth = this.resultImage.width;
              newHeight = this.resultImage.height;
              tempCanvas.width = newWidth;
              tempCanvas.height = newHeight;
              ctx.clearRect(0, 0, newWidth, newHeight);

              if (this.selectedBackgroundColor !== 'transparent') {
                ctx.fillStyle = this.selectedBackgroundColor;
                ctx.fillRect(0, 0, newWidth, newHeight);
              }

              const img = await loadImage(this.resultImage.src);
              ctx.drawImage(img, 0, 0);

              this.cropBoundaries = { minX: 0, maxX: newWidth - 1, minY: 0, maxY: newHeight - 1 };
            }
          } else {
            const [width, height] = this.selectedRatio.split(':').map(Number);
            const targetRatio = width / height;
            const currentRatio = this.initialResultImage.width / this.initialResultImage.height;

            if (currentRatio < targetRatio) {
              newHeight = this.initialResultImage.height;
              newWidth = newHeight * targetRatio;
            } else {
              newWidth = this.initialResultImage.width;
              newHeight = newWidth / targetRatio;
            }

            tempCanvas.width = newWidth;
            tempCanvas.height = newHeight;
            ctx.clearRect(0, 0, newWidth, newHeight);

            if (this.selectedBackgroundColor !== 'transparent') {
              ctx.fillStyle = this.selectedBackgroundColor;
              ctx.fillRect(0, 0, newWidth, newHeight);
            }

            const img = await loadImage(this.initialResultImage.src);
            const offsetX = Math.floor((newWidth - this.initialResultImage.width) / 2);
            const offsetY = Math.floor((newHeight - this.initialResultImage.height) / 2);
            ctx.drawImage(img, offsetX, offsetY);

            this.cropBoundaries = { minX: 0, maxX: newWidth - 1, minY: 0, maxY: newHeight - 1 };
          }

          const resultImg = new Image();
          resultImg.onload = () => {
            this.resultImage = {
              src: resultImg.src,
              width: newWidth,
              height: newHeight,
              originalSrc: this.initialResultImage.originalSrc || resultImg.src,
              hasAlphaChannel: true
            };

            // 重新渲染结果Canvas
            this.$nextTick(() => {
              this.renderResultCanvas();
              this.resizeCanvas();
              if (callback) callback();
            });
          };
          resultImg.onerror = () => {
            console.error('无法生成 resultImage');
            ElNotification({
              type: 'error',
              title: '错误',
              message: '无法生成调整后的图像'
            });
            if (callback) callback();
          };
          resultImg.src = tempCanvas.toDataURL('image/png');
        };

        processImage().catch((error) => {
          console.error('调整比例失败:', error);
          ElNotification({
            type: 'error',
            title: '错误',
            message: '调整比例失败，请重试'
          });
          if (callback) callback();
        });
      },

      // 新增：计算裁剪边界的方法
      calculateCropBoundaries() {
        if (!this.initialResultImage) return null;

        // 创建临时Canvas来分析图像数据
        const tempCanvas = document.createElement('canvas');
        const tempCtx = tempCanvas.getContext('2d', { willReadFrequently: true });

        // 加载图像
        return new Promise((resolve) => {
          const img = new Image();
          img.onload = () => {
            tempCanvas.width = img.width;
            tempCanvas.height = img.height;
            tempCtx.clearRect(0, 0, img.width, img.height);
            tempCtx.drawImage(img, 0, 0);

            const imageData = tempCtx.getImageData(0, 0, img.width, img.height);
            const data = imageData.data;
            const width = img.width;
            const height = img.height;

            // 从四条边向内查找内容边界
            let minX = width, maxX = -1, minY = height, maxY = -1;
            const alphaThreshold = 50;
            const edgePadding = 5;

            // 从左边向右查找第一个有内容的列
            for (let x = edgePadding; x < width - edgePadding; x++) {
              let hasContent = false;
              for (let y = edgePadding; y < height - edgePadding; y++) {
                const alpha = data[(y * width + x) * 4 + 3];
                if (alpha > alphaThreshold) {
                  hasContent = true;
                  break;
                }
              }
              if (hasContent) {
                minX = x;
                break;
              }
            }

            // 从右边向左查找最后一个有内容的列
            for (let x = width - edgePadding - 1; x >= edgePadding; x--) {
              let hasContent = false;
              for (let y = edgePadding; y < height - edgePadding; y++) {
                const alpha = data[(y * width + x) * 4 + 3];
                if (alpha > alphaThreshold) {
                  hasContent = true;
                  break;
                }
              }
              if (hasContent) {
                maxX = x;
                break;
              }
            }

            // 从上边向下查找第一个有内容的行
            for (let y = edgePadding; y < height - edgePadding; y++) {
              let hasContent = false;
              for (let x = edgePadding; x < width - edgePadding; x++) {
                const alpha = data[(y * width + x) * 4 + 3];
                if (alpha > alphaThreshold) {
                  hasContent = true;
                  break;
                }
              }
              if (hasContent) {
                minY = y;
                break;
              }
            }

            // 从下边向上查找最后一个有内容的行
            for (let y = height - edgePadding - 1; y >= edgePadding; y--) {
              let hasContent = false;
              for (let x = edgePadding; x < width - edgePadding; x++) {
                const alpha = data[(y * width + x) * 4 + 3];
                if (alpha > alphaThreshold) {
                  hasContent = true;
                  break;
                }
              }
              if (hasContent) {
                maxY = y;
                break;
              }
            }

            // 检查是否找到了有效的内容区域
            if (minX >= width || maxX < 0 || minY >= height || maxY < 0) {
              console.warn('无法检测到有效内容区域，使用原始尺寸');
              resolve(null);
              return;
            }

            // 添加一些边距
            const padding = 2;
            minX = Math.max(edgePadding, minX - padding);
            maxX = Math.min(width - edgePadding - 1, maxX + padding);
            minY = Math.max(edgePadding, minY - padding);
            maxY = Math.min(height - edgePadding - 1, maxY + padding);

            const cropWidth = maxX - minX + 1;
            const cropHeight = maxY - minY + 1;

            // 更新裁剪边界信息
            this.cropBoundaries = { minX, maxX, minY, maxY };

            resolve({
              minX, maxX, minY, maxY,
              cropWidth, cropHeight
            });
          };
          img.src = this.initialResultImage.src;
        });
      },

    }
  };
</script>

<style scoped>
  * {
    -webkit-user-drag: none;
  }

  /* 进度条样式 */
  .progress-bar {
    width: 100%;
    background-color: #f0f0f0;
    border-radius: 8px;
    margin: 15px 0;
    overflow: hidden;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
    height: 24px;
  }

  .progress {
    width: 0;
    height: 100%;
    background: linear-gradient(90deg, #3d8bff, #008cff);
    background-size: 200% 100%;
    border-radius: 6px;
    transition: width 1s cubic-bezier(0.22, 1, 0.36, 1);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    animation: gradient-shift 2s linear infinite;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1), 0 2px 4px rgba(0, 0, 0, 0.06);
    /* 添加阴影 */
  }

  .progress-text {
    color: white;
    font-size: 14px;
    font-weight: bold;
    text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5);
    position: relative;
    z-index: 2;
    padding: 0 8px;
    white-space: nowrap;
  }

  /* 添加移动渐变效果 */
  @keyframes gradient-shift {
    0% {
      background-position: 0% 50%;
    }

    50% {
      background-position: 100% 50%;
    }

    100% {
      background-position: 0% 50%;
    }
  }

  /* 预览图队列 */
  .preview-queue {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    padding: 10px 0;
    margin-bottom: 15px;
    border-bottom: 1px solid #ddd;
    max-width: 100%;
    overflow-x: hidden;
    max-height: 300px;
    overflow-y: auto;
  }


  .preview-item {
    position: relative;
    width: calc(20% - 10px);
    /* 每行显示 5 张，减去间距 */
    aspect-ratio: 1 / 1;
    /* 强制容器为方形 */
    width: 120px;
    /* 固定宽度 */
    height: 120px;
    /* 固定高度 */
    border-radius: 8px;
    overflow: hidden;
    cursor: pointer;
    border: 2px solid transparent;
    transition: border-color 0.3s;
    flex-shrink: 0;
    /* 防止图片被压缩 */
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #f0f0f0;
    /* 添加背景色，避免透明区域显得突兀 */
  }

  .preview-item img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  @media (max-width: 768px) {
    .preview-item {
      width: calc(33.33% - 10px);
      /* 小屏幕下每行显示 3 张 */
    }
  }

  @media (max-width: 480px) {
    .preview-item {
      width: calc(50% - 10px);
      /* 更小屏幕下每行显示 2 张 */
    }
  }

  .preview-item.active {
    border-color: #4086f4;
  }

  .preview-item.processing {
    opacity: 0.7;
  }

  .preview-item.completed {
    opacity: 1;
  }

  .preview-item:not(.completed) {
    opacity: 0.5;
  }

  .status-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .preview-queue .spinner {
    border: 3px solid rgba(255, 255, 255, 0.3);
    border-top: 3px solid #fff;
    width: 20px;
    height: 20px;
  }

  /* 模型选择 */
  .model-section {
    margin: 2rem 0;
    text-align: center;
    position: relative;
  }

  .model-label {
    display: block;
    margin-bottom: 0.5rem;
    font-size: 1.1em;
    color: #333;
  }

  .model-options {
    display: inline-flex;
    list-style: none;
    padding: 0;
    margin: 0;
    background-color: #f0f0f0;
    border-radius: 25px;
    overflow: hidden;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease;
  }

  .model-options:hover {
    box-shadow: 0 6px 8px rgba(0, 0, 0, 0.15);
  }

  .model-options li {
    padding: 12px 24px;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 15px;
    color: #333;
    display: flex;
    align-items: center;
    position: relative;
    overflow: hidden;
  }

  .model-options li:hover {
    background-color: #e0e0e0;
  }

  .model-options li.active {
    background-color: #007bff;
    color: white;
  }

  .model-options li:not(:last-child) {
    border-right: 1px solid #ddd;
  }

  .model-options li::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: rgba(255, 255, 255, 0.2);
    transition: all 0.3s ease;
  }

  .model-options li:hover::before {
    left: 100%;
  }

  /* Tooltip Styles */
  .model-tooltip {
    position: fixed;
    z-index: 9999;
    width: 320px;
    background-color: white;
    border-radius: 8px;
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.15);
    pointer-events: none;
    overflow: hidden;
    animation: fadeIn 0.2s ease-out;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(10px);
    }

    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .tooltip-content {
    padding: 12px;
  }

  .tooltip-content h4 {
    margin: 0 0 8px 0;
    font-size: 16px;
    color: #333;
  }

  .model-demo-video {
    width: 100%;
    height: auto;
    border-radius: 4px;
    margin-bottom: 10px;
  }

  .model-description {
    margin: 0;
    font-size: 14px;
    line-height: 1.4;
    color: #555;
  }

  /* 颜色选择部分 */
  .background-color-section {
    margin: 30px 0;
    text-align: center;
  }

  .background-color-section h3 {
    margin-bottom: 15px;
    font-size: 18px;
    color: #333;
  }

  .color-picker {
    display: flex;
    gap: 12px;
    align-items: center;
    justify-content: center;
    flex-wrap: wrap;
    margin: 15px auto;
    max-width: 500px;
  }

  .color-option {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    cursor: pointer;
    border: 2px solid #e0e0e0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    transition: all 0.2s ease;
    position: relative;
  }

  .color-option:hover {
    transform: scale(1.1);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .color-option.active {
    border-color: #007bff;
    box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.3);
  }

  .color-option[style*="transparent"] {
    background-image: linear-gradient(45deg, #ccc 25%, transparent 25%),
      linear-gradient(-45deg, #ccc 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, #ccc 75%),
      linear-gradient(-45deg, transparent 75%, #ccc 75%);
    background-size: 10px 10px;
    background-position: 0 0, 0 5px, 5px -5px, -5px 0px;
  }

  .color-option span {
    color: #333;
    font-size: 12px;
    background-color: rgba(255, 255, 255, 0.8);
    border-radius: 10px;
    padding: 2px 6px;
  }

  input[type="color"] {
    width: 36px;
    height: 36px;
    border: 2px solid #e0e0e0;
    border-radius: 50%;
    overflow: hidden;
    cursor: pointer;
    padding: 0;
    transition: all 0.2s ease;
  }

  input[type="color"]:hover {
    transform: scale(1.1);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  /* 彩色选色器样式 */
  .custom-color-wheel {
    position: relative;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    overflow: hidden;
    cursor: pointer;
    border: 2px solid #e0e0e0;
    transition: all 0.2s ease;
  }

  .custom-color-wheel:hover {
    transform: scale(1.1);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .custom-color-wheel.active {
    border-color: #007bff;
    box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.3);
  }

  /* 创建彩色选色器背景 */
  .custom-color-wheel::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: conic-gradient(#ff0000, #ff7f00, #ffff00, #00ff00, #0000ff, #4b0082, #9400d3, #ff0000);
  }

  /* 隐藏原始颜色输入框 */
  .custom-color-wheel input[type="color"] {
    opacity: 0;
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    cursor: pointer;
  }



  /* 下载区域整体布局 */
  .download-section {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 20px;
    margin: 30px 0;
    flex-wrap: wrap;
  }

  /* 下载模式切换容器 */
  .download-mode-toggle {
    display: inline-flex;
    position: relative;
    background-color: #e6f0fa;
    border-radius: 50px;
    padding: 4px;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.05);
    overflow: hidden;
    width: 200px;
  }

  /* 滑动背景元素 - 现在是独立的div */
  .toggle-slider {
    position: absolute;
    top: 4px;
    left: 4px;
    width: calc(50% - 4px);
    height: calc(100% - 8px);
    background-color: #4086f4;
    border-radius: 50px;
    transition: transform 0.3s ease;
    z-index: 0;
  }

  /* 按钮样式 */
  .download-mode-toggle button {
    flex: 1;
    padding: 10px 0;
    border: none;
    background: none;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    color: #666;
    border-radius: 20px;
    transition: color 0.3s ease;
    position: relative;
    z-index: 1;
    text-align: center;
  }

  /* 激活状态的文字颜色 */
  .download-mode-toggle button.active {
    color: white;
  }

  /* 悬停效果 */
  .download-mode-toggle button:hover:not(.active) {
    color: #4086f4;
  }

  /* 下载按钮 */
  .download-btn {
    padding: 12px 24px;
    border-radius: 50px;
    font-size: 16px;
    font-weight: 500;
    background-color: #4086f4;
    color: white;
    border: none;
    box-shadow: 0 4px 8px rgba(64, 134, 244, 0.25);
    transition: all 0.3s ease;
    min-width: 180px;
  }

  .download-btn:hover {
    background-color: #3370d6;
    box-shadow: 0 6px 12px rgba(64, 134, 244, 0.3);
    transform: translateY(-2px);
  }

  .download-btn:disabled {
    background-color: #86b7fe;
    cursor: not-allowed;
    transform: none;
  }

  /* 再次上传按钮 */
  .upload-again-btn {
    padding: 12px 24px;
    border-radius: 50px;
    font-size: 16px;
    font-weight: 500;
    background-color: white;
    border: 1px solid #e0e0e0;
    color: #333;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.05);
    transition: all 0.3s ease;
    min-width: 180px;
  }

  .upload-again-btn:hover {
    background-color: #f8f9fa;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.08);
    transform: translateY(-2px);
  }

  /* 图标间距 */
  .mr-2 {
    margin-right: 8px;
  }

  /* 响应式调整 */
  @media (max-width: 600px) {
    .download-section {
      flex-direction: column;
      gap: 15px;
    }

    .download-mode-toggle {
      max-width: 200px;
    }

    .download-btn,
    .upload-again-btn {
      width: 100%;
      max-width: 300px;
    }
  }

  /* 总体 */
  .image-matting-container {
    font-family: Arial, sans-serif;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }

  .header {
    text-align: center;
    margin-bottom: 30px;
  }

  .title {
    font-size: 32px;
    font-weight: bold;
    margin-bottom: 10px;
  }

  .subtitle {
    font-size: 16px;
    color: #666;
  }

  .content-wrapper {
    display: flex;
    gap: 20px;
  }

  .context-describe {
    color: #757575;
    line-height: 8px;
    font-size: 0.9rem;
  }

  .examples-section {
    flex: 1;
    max-width: 400px;
    display: flex;
    flex-direction: column;
    align-items: center;
    /* 内容水平居中 */
    justify-content: center;
    /* 内容垂直居中 */
  }

  .video-placeholder {
    background-color: #f0f0f0;
    border-radius: 15px;
    height: auto;
    border: 1px #ccc;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* 当视频栏隐藏时，调整图像栏的布局 */
  .examples-section:not(:has(.video-placeholder)) {
    max-width: 0%;
    /* 占据整个左侧区域 */
    justify-content: center;
    /* 内容居中 */
  }

  .example-images {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 10px;
  }

  .example-image {
    border-radius: 12px;
    overflow: hidden;
    background-color: #f9f9f9;
    aspect-ratio: 1/1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .example-image img {
    max-width: 100%;
    max-height: 100%;
  }

  .processing-section {
    flex: 2;
    /*   border: 1px dashed #ccc;
 */
    border-radius: 12px;

    min-height: 400px;
    display: flex;
    flex-direction: column;
  }

  .upload-area {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 15px;
    border: 2px dashed #ccc;
    padding: 30px;
    transition: background-color 0.3s, border-color 0.3s;
    /* 添加过渡效果 */
    background-color: #fafafa;
  }

  .upload-area:hover {
    border-color: #007bff;
    /* 鼠标悬停时边框颜色变化 */
    background-color: #f0f8ff;
    /* 鼠标悬停时背景颜色变化 */
  }

  .upload-content {
    text-align: center;
    max-width: 400px;
  }

  .upload-icon {
    margin-bottom: 15px;
  }

  .upload-icon img {
    width: auto;
    height: 100px;
  }

  .upload-buttons {
    display: flex;
    justify-content: center;
    gap: 10px;
    margin: 20px 0;
  }

  .btn {
    padding: 12px 24px;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-weight: 500;
    min-width: 160px;
    transition: all 0.3s ease;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
  }

  .upload-btn {
    background-color: #4086f4;
    color: white;
  }

  .upload-btn:hover {
    background-color: #3370d6;
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
  }

  .batch-upload-btn {
    background-color: white;
    border: 1px solid #4086f4;
    color: #4086f4;
  }

  .batch-upload-btn:hover {
    background-color: #f0f8ff;
    color: #3370d6;
    border-color: #3370d6;
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  }

  .image-processing-area {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  .tabs {
    display: flex;
    border-bottom: 1px solid #ddd;
    margin-bottom: 15px;
  }

  .tab {
    padding: 10px 20px;
    cursor: pointer;
    position: relative;
    transition: all 0.3s ease;
    color: #333;
  }

  .tab.active {
    font-weight: bold;
    color: #4086f4;
  }

  .tab::after {
    content: '';
    position: absolute;
    bottom: -1px;
    left: 50%;
    width: 0;
    height: 2px;
    background-color: #4086f4;
    transition: all 0.3s ease;
    transform: translateX(-50%);
  }

  .tab.active::after {
    width: 100%;
  }

  .tab:hover {
    color: #4086f4;
  }

  .image-display-area {
    flex: 1;
    position: relative;
    min-height: 300px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 20px;
  }

  .image-canvas-wrapper {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    max-height: 500px;
    /* 限制最大高度 */
  }

  .image-canvas-wrapper canvas,
  .image-canvas-wrapper img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
  }

  .checkerboard {
    background-image: linear-gradient(45deg, #f0f0f0 25%, transparent 25%),
      linear-gradient(-45deg, #f0f0f0 25%, transparent 25%),
      linear-gradient(45deg, transparent 75%, #f0f0f0 75%),
      linear-gradient(-45deg, transparent 75%, #f0f0f0 75%);
    background-size: 20px 20px;
    background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .processing-overlay {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(255, 255, 255, 0.8);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }

  .spinner {
    border: 4px solid rgba(0, 0, 0, 0.1);
    border-radius: 50%;
    border-top: 4px solid #4086f4;
    width: 30px;
    height: 30px;
    animation: spin 1s linear infinite;
    margin-bottom: 10px;
  }

  @keyframes spin {
    0% {
      transform: rotate(0deg);
    }

    100% {
      transform: rotate(360deg);
    }
  }

  .editing-tools {
    padding: 15px 0;
  }

  .tool-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 15px;
  }

  .tool-btn {
    background-color: #f0f0f0;
    border: none;
    padding: 8px 12px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 5px;
  }

  /* 比例标签部分 */
  .ratio-section {
    margin: 15px 0;
  }

  .ratio-options {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    gap: 10px;
    justify-content: flex-start;
    max-width: 100%;
    overflow-x: auto;
  }

  .ratio-option {
    display: flex;
    flex-direction: column;
    align-items: center;
    cursor: pointer;
    padding: 8px;
    border-radius: 8px;
    transition: all 0.3s ease;
    width: 60px;
    position: relative;
    /* 用于层叠控制 */
  }

  .ratio-option:hover {
    background-color: rgba(64, 134, 244, 0.1);
    /* 悬停状态：浅蓝色背景 */
  }

  .ratio-option.active {
    border: 2px solid #4086f4;
    /* 蓝色边框 */
    background-color: rgba(64, 134, 244, 0.1);
    /* 浅蓝色填充 */
    color: white;
    /* 激活状态下文字为白色 */
    border-radius: 8px;
    /* 圆角 */
    padding: 6px;
    /* 调整内边距以适应边框 */
  }

  .ratio-icon {
    display: flex;
    justify-content: center;
    align-items: center;
    width: 36px;
    height: 36px;
    border-radius: 4px;
    background-color: transparent;
    /* 图标区域保持透明 */
    margin-bottom: 6px;
    /* 图标和标签之间的间距 */
  }

  .ratio-option.active .ratio-icon {
    background-color: transparent;
    /* 确保图标区域在激活状态下仍然透明 */
  }

  /* 保持所有图标（包括 Font Awesome 和 img）在激活状态下的灰黑色 */
  .ratio-option.active .ratio-icon img,
  .ratio-option.active .ratio-icon .icon-24 {
    filter: none;
    /* 确保 img 图标不应用滤镜，保持灰黑色 */
    color: #555;
    /* 强制 Font Awesome 图标颜色为灰黑色，覆盖父元素的 color: white */
  }

  .ratio-icon img {
    width: 24px;
    height: 24px;
  }

  .ratio-label {
    margin-top: 6px;
    font-size: 12px;
    color: #555;
    text-align: center;
  }

  .ratio-option.active .ratio-label {
    color: rgb(66, 66, 66);
    /* 激活状态下标签文字为白色 */
  }

  /* 图标样式 */
  .icon-upload,
  .icon-batch,
  .icon-process,
  .icon-download,
  .icon-upload-again {
    display: inline-block;
    width: 16px;
    height: 16px;
    background-size: contain;
    background-repeat: no-repeat;
  }

  /* 响应式布局 */
  @media (max-width: 900px) {
    .content-wrapper {
      flex-direction: column;
    }

    .examples-section {
      max-width: 100%;
    }
  }

  @media (min-width: 900px) {
    .examples-section:not(:has(.video-placeholder)) {
      max-width: 100%;
      /* 占据整个左侧区域 */
      justify-content: center;
      /* 内容居中 */
    }
  }


  /* 滚动条 */
  /* WebKit 浏览器（Chrome、Safari、Edge） */
  ::-webkit-scrollbar {
    width: 12px;
    height: 12px;
  }

  ::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 10px;
  }

  ::-webkit-scrollbar-thumb {
    background: #888;
    border-radius: 10px;
    border: 3px solid #f1f1f1;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: #555;
  }

  /* Firefox 浏览器 */
  html {
    scrollbar-width: thin;
    scrollbar-color: #888 #f1f1f1;
  }
</style>
