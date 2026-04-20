<template>
    <div class="app-container">
        <!-- 主内容区域 -->
        <main class="main-content">
            <!-- 主页面 -->
            <div v-if="showUploadBox" class="homepage">
                <!-- 头部标题区域 -->
                <div class="header-section">
                    <h1 class="main-title">AI 图像修复工具</h1>
                    <p class="main-subtitle">AI智能消除笔，一键去除图片中的不需要元素，让图像完美无瑕。</p>
                </div>

                <!-- 主要内容区域 -->
                <div class="main-section">
                    <!-- 左侧演示视频 -->
                    <div class="demo-section">
                        <div class="demo-video">
                            <video 
                                :src="demoVideo" 
                                controls 
                                autoplay 
                                muted 
                                loop 
                                class="demo-video-player"
                                poster=""
                            >
                                <source :src="demoVideo" type="video/mp4">
                                您的浏览器不支持视频播放。
                            </video>
                        </div>
                        <div class="demo-description">
                            <h3>观看演示视频</h3>
                            <p>了解如何使用AI工具快速修复图像</p>
                        </div>
                    </div>

                    <!-- 右侧上传区域 -->
                    <div class="upload-section">
                        <div class="upload-container">
                            <div class="upload-box" @dragover.prevent @drop.prevent="handleDrop"
                                @click="$refs.imageInput.click()">
                                <input type="file" ref="imageInput" @change="handleImageUpload" accept="image/*" class="upload-input">
                                <div class="upload-content">
                                    <div class="upload-icon">
                                        <font-awesome-icon icon="image" />
                                    </div>
                                    <h3 class="upload-title">粘贴图片、网址，或拖拽图片至此。</h3>
                                    <p class="upload-description">支持 JPG、PNG、WebP 格式</p>
                                    <div class="upload-buttons">
                                        <button class="btn-upload-primary">
                                            <font-awesome-icon icon="cloud-upload-alt" />
                                            上传图片
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 工作区域 -->
            <div class="workspace" v-if="currentImage">
                <!-- 左侧工具栏 -->
                <div class="left-sidebar">
                    <div class="tool-section">
                        <h3 class="section-title">AI 图像修复工具</h3>
                        <div class="tool-group">
                            <button @click="reUploadImage" class="btn btn-full btn-outline">
                                <font-awesome-icon icon="upload" />
                                重新选择图片
                            </button>
                        </div>
                    </div>

                    <div class="tool-section">
                        <h3 class="section-title">绘制工具</h3>
                        <div class="tool-group">
                            <label class="tool-item">
                                <span class="tool-label">画笔大小</span>
                                <div class="brush-control">
                                    <input type="range" v-model="brushSize" :min="minBrushSize" :max="maxBrushSize" 
                                           step="1" class="brush-slider">
                                    <span class="brush-value">{{ Math.round(brushSize) }}px</span>
                                </div>
                            </label>
                        </div>
                        <div class="tool-group">
                            <button @click="clearCanvas" class="btn btn-full btn-secondary">
                                <font-awesome-icon icon="eraser" />
                                清除标记
                            </button>
                        </div>
                    </div>

                    <div class="tool-section">
                        <h3 class="section-title">缩放控制</h3>
                        <div class="zoom-controls-sidebar">
                            <div class="zoom-info">
                                <span class="zoom-label">缩放比例</span>
                                <span class="zoom-value">{{ Math.round(scale * 100) }}%</span>
                            </div>
                            <div class="zoom-buttons">
                                <button @click="zoomOut" class="btn btn-zoom">
                                    <font-awesome-icon icon="search-minus" />
                                </button>
                                <button @click="resetZoom" class="btn btn-zoom">
                                    <font-awesome-icon icon="expand" />
                                </button>
                                <button @click="zoomIn" class="btn btn-zoom">
                                    <font-awesome-icon icon="search-plus" />
                                </button>
                            </div>
                        </div>
                    </div>

                    <div class="tool-section action-section">
                        <div class="action-buttons">
                            <button @click="submitInpainting" class="btn btn-primary btn-large" :disabled="isProcessing">
                                <font-awesome-icon icon="magic" v-if="!isProcessing" />
                                <font-awesome-icon icon="spinner" spin v-else />
                                {{ isProcessing ? '修复中...' : '开始修复' }}
                            </button>
                            <button @click="downloadImage" class="btn btn-success btn-large" :disabled="!hasResultImage">
                                <font-awesome-icon icon="download" />
                                下载结果
                            </button>
                        </div>
                    </div>

                    <div class="tool-section">
                        <h3 class="section-title">操作指南</h3>
                        <div class="action-info">
                            <div class="tip-card">
                                <font-awesome-icon icon="info-circle" />
                                <p>用画笔标记需要修复的区域，然后点击开始修复</p>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 画布区域 -->
                <div class="canvas-section">
                    <div class="canvas-container" ref="canvasContainer">
                        <div class="canvas-wrapper" ref="canvasWrapper">
                            <img :src="currentImage" alt="当前图像" ref="displayImage" class="display-image">
                            <canvas ref="canvas" 
                                    class="drawing-canvas"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </main>

        <!-- 功能特色组件 -->
        <FeaturesSection />

        <!-- 加载遮罩 -->
        <div v-if="isProcessing" class="loading-overlay">
            <div class="loading-content">
                <div class="loading-spinner"></div>
                <h3>AI 正在修复图像...</h3>
                <p>请稍候，这可能需要几秒钟</p>
            </div>
        </div>
    </div>
</template>

<script>
import axios from 'axios'
import FeaturesSection from './FeaturesSection.vue'
import demoVideo from '@/assets/展示视频.mp4'
import { ElNotification } from 'element-plus'

export default {
    components: {
        FeaturesSection
    },
    data() {
        return {
            imageFile: null,
            currentImage: null,
            drawing: false,
            ctx: null,
            canvas: null,
            maskCanvas: null,
            maskCtx: null,
            tempCanvas: null,
            tempCtx: null,
            savedImageData: null,
            brushSize: 20,
            minBrushSize: 5,
            maxBrushSize: 50,
            scale: 1,
            translateX: 0,
            translateY: 0,
            isDragging: false,
            startX: 0,
            startY: 0,
            lastX: null,
            lastY: null,
            showUploadBox: true,
            isProcessing: false,
            imageNaturalWidth: 0,
            imageNaturalHeight: 0,
            previewCanvas: null,
            previewCtx: null,
            showBrushPreview: false,
            previewX: 0,
            previewY: 0,
            demoVideo: demoVideo,
            hasResultImage: false, // 新增，表示是否有修复结果
        }
    },
    mounted() {
        this.maskCanvas = document.createElement('canvas');
        this.maskCtx = this.maskCanvas.getContext('2d');
        this.updateCursor();

        this.$nextTick(() => {
            if (!this.$refs.imageInput) {
                console.warn('imageInput ref is not mounted yet');
            }
        });

        // 监听窗口大小变化，防抖后自动居中缩放
        this._resizeTimeout = null;
        this._onResize = () => {
            if (this._resizeTimeout) clearTimeout(this._resizeTimeout);
            this._resizeTimeout = setTimeout(() => {
                if (this.currentImage) this.resetZoom();
            }, 300);
        };
        window.addEventListener('resize', this._onResize);
    },
    beforeUnmount() {
        window.removeEventListener('resize', this._onResize);
        if (this._resizeTimeout) clearTimeout(this._resizeTimeout);
    },
    watch: {
        brushSize(newSize) {
            if (this.ctx && this.maskCtx && this.tempCtx) {
                this.ctx.lineWidth = newSize;
                this.maskCtx.lineWidth = newSize;
                this.tempCtx.lineWidth = newSize;
                this.updateCursor();
            }
            this.clearBrushPreview();
        },
        scale() {
            this.updateCursor();
        },
        currentImage() {
            this.updateCursor();
        }
    },
    methods: {
        handleImageUpload(event) {
            this.imageFile = event.target.files[0]
            this.currentImage = URL.createObjectURL(this.imageFile)
            this.loadImageToCanvas(false)
            this.showUploadBox = false;
            this.hasResultImage = false; // 上传后无修复结果
        },
        handleDrop(event) {
            const file = event.dataTransfer.files[0]
            if (file && file.type.startsWith('image/')) {
                this.imageFile = file
                this.currentImage = URL.createObjectURL(this.imageFile)
                this.loadImageToCanvas(false)
                this.showUploadBox = false;
                this.hasResultImage = false; // 上传后无修复结果
            }
        },
        reUploadImage() {
            this.currentImage = null;
            this.imageFile = null;
            this.showUploadBox = true;
            this.isProcessing = false;
            this.hasResultImage = false; // 重新上传也无修复结果
            if (this.ctx) {
                this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
            }
            if (this.tempCtx) {
                this.tempCtx.clearRect(0, 0, this.tempCanvas.width, this.tempCanvas.height);
            }
            if (this.maskCtx) {
                this.maskCtx.fillStyle = 'black';
                this.maskCtx.fillRect(0, 0, this.maskCanvas.width, this.maskCanvas.height);
            }
            this.clearBrushPreview();
            // 移除预览画布
            if (this.previewCanvas && this.previewCanvas.parentNode) {
                this.previewCanvas.parentNode.removeChild(this.previewCanvas);
            }
        },
        loadImageToCanvas(preserveBrushSize = false) {
            const img = new Image();
            img.onload = () => {
                this.canvas = this.$refs.canvas;
                this.ctx = this.canvas.getContext('2d');
                
                this.imageNaturalWidth = img.width;
                this.imageNaturalHeight = img.height;

                const container = this.$refs.canvasContainer;
                const wrapper = this.$refs.canvasWrapper;
                
                // 添加缩放事件监听器
                container.addEventListener('wheel', this.handleWheel, { passive: false });
                
                // 添加拖拽和绘制的统一事件监听器
                wrapper.addEventListener('mousedown', this.handleCanvasMouseDown);
                wrapper.addEventListener('mousemove', this.handleCanvasMouseMove);
                wrapper.addEventListener('mouseup', this.handleCanvasMouseUp);
                wrapper.addEventListener('mouseleave', this.handleCanvasMouseLeave);

                // 计算初始缩放和位置
                const containerRect = container.getBoundingClientRect();
                const maxWidth = containerRect.width - 40;
                const maxHeight = containerRect.height - 40;
                const scaleX = maxWidth / img.width;
                const scaleY = maxHeight / img.height;
                this.scale = Math.min(scaleX, scaleY, 1);

                this.translateX = (containerRect.width - img.width * this.scale) / 2;
                this.translateY = (containerRect.height - img.height * this.scale) / 2;
                this.updateTransform();

                // 设置画布尺寸
                this.canvas.width = img.width;
                this.canvas.height = img.height;
                this.maskCanvas.width = img.width;
                this.maskCanvas.height = img.height;
                
                // 创建临时画布用于绘制单个笔触
                this.tempCanvas = document.createElement('canvas');
                this.tempCtx = this.tempCanvas.getContext('2d');
                this.tempCanvas.width = img.width;
                this.tempCanvas.height = img.height;
                
                // 创建预览画布用于显示大笔刷预览
                this.previewCanvas = document.createElement('canvas');
                this.previewCtx = this.previewCanvas.getContext('2d');
                this.previewCanvas.width = img.width;
                this.previewCanvas.height = img.height;
                this.previewCanvas.style.position = 'absolute';
                this.previewCanvas.style.top = '0';
                this.previewCanvas.style.left = '0';
                this.previewCanvas.style.pointerEvents = 'none';
                this.previewCanvas.style.zIndex = '10';
                this.previewCanvas.style.width = `${img.width}px`;
                this.previewCanvas.style.height = `${img.height}px`;
                
                // 将预览画布添加到包装器中
                wrapper.appendChild(this.previewCanvas);
                
                // 确保画布背景透明
                this.ctx.clearRect(0, 0, img.width, img.height);

                // 设置显示图像尺寸
                this.$refs.displayImage.style.width = `${img.width}px`;
                this.$refs.displayImage.style.height = `${img.height}px`;

                // 初始化mask画布
                this.maskCtx.fillStyle = 'black';
                this.maskCtx.fillRect(0, 0, img.width, img.height);

                // 根据图像大小调整画笔尺寸范围
                const imageScale = Math.max(img.width, img.height) / 1000;
                this.minBrushSize = Math.max(5, Math.round(5 * imageScale));
                this.maxBrushSize = Math.min(100, Math.round(50 * imageScale));
                if (!preserveBrushSize) {
                    this.brushSize = Math.round(20 * imageScale);
                } else {
                    // 保证brushSize在新范围内
                    this.brushSize = Math.max(this.minBrushSize, Math.min(this.brushSize, this.maxBrushSize));
                }

                // 设置画笔属性
                this.ctx.strokeStyle = 'rgba(79, 150, 255, 0.8)';
                this.ctx.fillStyle = 'rgba(79, 150, 255, 0.8)';
                this.ctx.lineWidth = this.brushSize;
                this.ctx.lineCap = 'round';
                this.ctx.lineJoin = 'round';
                this.ctx.globalCompositeOperation = 'source-over';
                
                // 设置临时画布属性
                this.tempCtx.strokeStyle = 'rgba(79, 150, 255, 1.0)';
                this.tempCtx.fillStyle = 'rgba(79, 150, 255, 1.0)';
                this.tempCtx.lineWidth = this.brushSize;
                this.tempCtx.lineCap = 'round';
                this.tempCtx.lineJoin = 'round';
                this.tempCtx.globalCompositeOperation = 'source-over';
                
                this.maskCtx.strokeStyle = 'white';
                this.maskCtx.fillStyle = 'white';
                this.maskCtx.lineWidth = this.brushSize;
                this.maskCtx.lineCap = 'round';
                this.maskCtx.lineJoin = 'round';
                this.maskCtx.globalCompositeOperation = 'source-over';

                this.updateCursor();
            };
            img.src = this.currentImage;
        },
        startDrawing(event) {
            if (!this.currentImage || event.button !== 0) return;
            this.drawing = true;
            const { x, y } = this.getCanvasCoordinates(event);
            
            // 清除预览
            this.clearBrushPreview();
            
            // 保存当前主画布状态
            this.savedImageData = this.ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
            
            // 清空临时画布开始新的笔触
            this.tempCtx.clearRect(0, 0, this.tempCanvas.width, this.tempCanvas.height);
            
            // 在临时画布上开始路径绘制
            this.tempCtx.beginPath();
            this.tempCtx.moveTo(x, y);
            this.tempCtx.lineTo(x, y);
            this.tempCtx.stroke();
            
            // 实时显示效果
            this.updateCanvas();
            
            // 在mask画布上绘制起始点
            this.maskCtx.beginPath();
            this.maskCtx.moveTo(x, y);
            this.maskCtx.lineTo(x, y);
            this.maskCtx.stroke();
            
            this.lastX = x;
            this.lastY = y;
        },
        draw(event) {
            if (!this.drawing) return;

            const { x, y } = this.getCanvasCoordinates(event);

            if (this.lastX === null || this.lastY === null) {
                this.lastX = x;
                this.lastY = y;
                return;
            }

            const dx = x - this.lastX;
            const dy = y - this.lastY;
            const distance = Math.sqrt(dx * dx + dy * dy);

            if (distance < 2) return;

            // 在临时画布上绘制连续线条
            this.tempCtx.lineTo(x, y);
            this.tempCtx.stroke();

            // 在mask画布上绘制连续线条
            this.maskCtx.lineTo(x, y);
            this.maskCtx.stroke();

            // 实时更新显示
            this.updateCanvas();

            this.lastX = x;
            this.lastY = y;
        },
        updateCanvas() {
            // 恢复保存的画布状态
            this.ctx.putImageData(this.savedImageData, 0, 0);
            
            // 以指定透明度绘制当前笔触
            this.ctx.globalAlpha = 0.8;
            this.ctx.drawImage(this.tempCanvas, 0, 0);
            this.ctx.globalAlpha = 1.0;
        },
        stopDrawing() {
            if (!this.drawing) return;
            
            // 结束路径绘制
            this.tempCtx.closePath();
            this.maskCtx.closePath();
            
            // 最终确认绘制效果（已经通过updateCanvas实时更新了）
            this.drawing = false;
            this.lastX = null;
            this.lastY = null;
            this.savedImageData = null;
        },
        clearCanvas() {
            if (this.currentImage) {
                this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height)
                this.tempCtx.clearRect(0, 0, this.tempCanvas.width, this.tempCanvas.height)
                this.maskCtx.fillStyle = 'black'
                this.maskCtx.fillRect(0, 0, this.canvas.width, this.canvas.height)
                this.clearBrushPreview()
            }
        },
        async submitInpainting() {
            console.log('开始修复处理...');
            if (!this.imageFile) {
                alert('请上传图像');
                return;
            }

            console.log('图像文件存在，开始处理...');
            this.isProcessing = true;

            try {
                const imageBlob = await this.convertImageToWebP(this.imageFile, 0.95);
                console.log('WebP 图像大小:', (imageBlob.size / 1024).toFixed(2), 'KB');

                const maskBlob = await new Promise(resolve => {
                    this.maskCanvas.toBlob(blob => resolve(blob), 'image/png');
                });

                console.log('Mask 图像大小:', (maskBlob.size / 1024).toFixed(2), 'KB');

                const formData = new FormData();
                formData.append('image', imageBlob, 'image.webp');
                formData.append('mask', maskBlob, 'mask.png');

                console.log('准备发送请求到后端...');
                const response = await axios.post('https://creatinf.com/inpaint', formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data'
                    },
                    responseType: 'blob'
                });

                console.log('收到后端响应，状态码:', response.status);
                console.log('响应数据大小:', response.data.size, 'bytes');
                
                this.currentImage = URL.createObjectURL(response.data);
                this.imageFile = response.data;
                this.loadImageToCanvas(true);
                this.clearCanvas();
                this.hasResultImage = true; // 修复成功后可下载
                
                console.log('修复完成，图像已更新');
            } catch (error) {
                console.error('修复过程中发生错误:', error);
                if (error.response) {
                    console.error('服务器响应错误:', error.response.status, error.response.data);
                    ElNotification({
                        title: '修复失败',
                        message: `服务器返回错误 ${error.response.status}`,
                        type: 'error',
                        duration: 5000
                    });
                } else if (error.request) {
                    console.error('网络请求失败:', error.request);
                    ElNotification({
                        title: '修复失败',
                        message: '无法连接到服务器，请检查后端服务是否正常运行',
                        type: 'error',
                        duration: 5000
                    });
                } else {
                    console.error('其他错误:', error.message);
                    ElNotification({
                        title: '修复失败',
                        message: error.message,
                        type: 'error',
                        duration: 5000
                    });
                }
            } finally {
                console.log('处理完成，重置状态');
                this.isProcessing = false;
            }
        },
        async convertImageToWebP(file, quality) {
            return new Promise((resolve, reject) => {
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    canvas.width = img.width;
                    canvas.height = img.height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, img.width, img.height);

                    canvas.toBlob(blob => {
                        if (blob) resolve(blob);
                        else reject(new Error('WebP 转换失败'));
                    }, 'image/webp', quality);
                };
                img.onerror = reject;
                img.src = URL.createObjectURL(file);
            });
        },
        updateCursor() {
            if (!this.canvas) return;
            
            // 计算实际显示大小
            const actualDisplaySize = this.brushSize * this.scale;
            const maxBrowserCursorSize = 128; // 浏览器支持的最大光标尺寸
            const maxHotspotDistance = 32; // 大多数浏览器的hotspot限制
            
            // 如果光标过大，使用替代方案
            if (actualDisplaySize > maxBrowserCursorSize || actualDisplaySize > maxHotspotDistance * 2) {
                // 使用简单的十字光标配合实时预览圆圈
                this.canvas.style.cursor = 'crosshair';
                if (this.$refs.canvasWrapper) {
                    this.$refs.canvasWrapper.style.cursor = 'crosshair';
                }
                this.showBrushPreview = true;
                return;
            } else {
                this.showBrushPreview = false;
                this.clearBrushPreview();
            }
            
            // 对于合理大小的光标，创建准确的预览
            const minCursorSize = 8;
            let displaySize = Math.max(actualDisplaySize, minCursorSize);
            
            const canvasSize = Math.ceil(displaySize) + 4; // 添加一些边距
            const cursorCanvas = document.createElement('canvas');
            cursorCanvas.width = canvasSize;
            cursorCanvas.height = canvasSize;
            const cursorCtx = cursorCanvas.getContext('2d');

            const centerX = canvasSize / 2;
            const centerY = canvasSize / 2;
            const radius = displaySize / 2;

            // 绘制外圈 - 半透明蓝色边框
            cursorCtx.beginPath();
            cursorCtx.arc(centerX, centerY, radius - 1, 0, Math.PI * 2);
            cursorCtx.strokeStyle = 'rgba(79, 150, 255, 0.8)';
            cursorCtx.lineWidth = 2;
            cursorCtx.stroke();

            // 绘制内圈 - 半透明蓝色填充
            cursorCtx.beginPath();
            cursorCtx.arc(centerX, centerY, radius - 1, 0, Math.PI * 2);
            cursorCtx.fillStyle = 'rgba(79, 150, 255, 0.2)';
            cursorCtx.fill();

            // 添加中心点
            cursorCtx.beginPath();
            cursorCtx.arc(centerX, centerY, 1, 0, Math.PI * 2);
            cursorCtx.fillStyle = 'rgba(79, 150, 255, 0.9)';
            cursorCtx.fill();

            const cursorDataUrl = cursorCanvas.toDataURL('image/png');
            const cursorStyle = `url(${cursorDataUrl}) ${centerX} ${centerY}, auto`;

            this.canvas.style.cursor = cursorStyle;
            
            // 同时设置包装器的光标样式
            if (this.$refs.canvasWrapper) {
                this.$refs.canvasWrapper.style.cursor = cursorStyle;
            }
        },
        // 工具函数：生成图片hash（可用md5库，简单实现如下）
        getImageHash(url) {
            let hash = 0, i, chr;
            if (!url) return '';
            for (i = 0; i < url.length; i++) {
                chr = url.charCodeAt(i);
                hash = ((hash << 5) - hash) + chr;
                hash |= 0;
            }
            return Math.abs(hash).toString();
        },
        // 更新本地配额
        updateUserQuotaInfo(quotaInfo) {
            if (quotaInfo) {
                let userInfo = JSON.parse(localStorage.getItem('userInfo') || '{}');
                userInfo.daily_free_images = quotaInfo.daily_free_images;
                userInfo.remaining_images = quotaInfo.remaining_images;
                localStorage.setItem('userInfo', JSON.stringify(userInfo));
            }
        },
        async downloadImage() {
            if (!this.currentImage) return;
            try {
                // 1. 先请求扣费接口
                const imageHash = this.getImageHash(this.currentImage);
                const resp = await axios.post('https://creatinf.com/check_download_quota', {
                    imageHash,
                    modelType: 'inpaint'
                }, { withCredentials: true });

                // 2. 判断返回
                if (resp.data.success) {
                    if (resp.data.quotaInfo) this.updateUserQuotaInfo(resp.data.quotaInfo);
                    // 允许下载
                    ElNotification({
                        title: '下载成功',
                        message: '图片已开始下载',
                        type: 'success',
                        duration: 3000
                    });
                } else if (resp.data.error && resp.data.error.includes('已下载过')) {
                    // 允许下载（不重复扣费）
                    ElNotification({
                        title: '下载成功',
                        message: '图片已开始下载（已下载过，不重复扣费）',
                        type: 'success',
                        duration: 3000
                    });
                } else {
                    ElNotification({
                        title: '下载失败',
                        message: resp.data.error || '下载配额不足，无法下载',
                        type: 'error',
                        duration: 5000
                    });
                    return;
                }

                // 3. 下载图片（加水印）
                const img = new window.Image();
                img.crossOrigin = 'anonymous';
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    canvas.width = img.width;
                    canvas.height = img.height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0);
                    // 添加水印
                    const text = '由创意无限AI生成';
                    const fontSize = Math.max(Math.round(img.width / 70), 10);
                    ctx.font = `bold ${fontSize}px sans-serif`;
                    ctx.textBaseline = 'bottom';
                    ctx.textAlign = 'right';
                    ctx.globalAlpha = 0.45;
                    const padding = Math.max(Math.round(img.width / 50), 12);
                    ctx.fillStyle = '#222';
                    ctx.fillText(text, img.width - padding, img.height - padding);
                    ctx.globalAlpha = 1.0;
                    // 下载
                    canvas.toBlob(blob => {
                        const url = URL.createObjectURL(blob);
                        const link = document.createElement('a');
                        link.href = url;
                        link.download = '创意无限—消除笔处理结果.png';
                        document.body.appendChild(link);
                        link.click();
                        document.body.removeChild(link);
                        URL.revokeObjectURL(url);
                    }, 'image/png');
                };
                img.src = this.currentImage;
            } catch (err) {
                // 检查是否是验证失败的情况
                if (err.response && err.response.status === 401) {
                    ElNotification({
                        title: '验证失败',
                        message: '请先登录后再下载',
                        type: 'warning',
                        duration: 5000
                    });
                } else if (err.response && err.response.status === 403) {
                    ElNotification({
                        title: '权限不足',
                        message: '请先登录后再下载',
                        type: 'warning',
                        duration: 5000
                    });
                } else {
                    ElNotification({
                        title: '下载失败',
                        message: err.response?.data?.error || err.message || '下载图片失败，请重试',
                        type: 'error',
                        duration: 5000
                    });
                }
            }
        },
        // 缩放控制方法
        zoomIn() {
            this.scale = Math.min(this.scale * 1.2, 5);
            this.updateTransform();
        },
        zoomOut() {
            this.scale = Math.max(this.scale / 1.2, 0.1);
            this.updateTransform();
        },
        resetZoom() {
            if (!this.imageNaturalWidth || !this.imageNaturalHeight) return;
            
            const container = this.$refs.canvasContainer;
            const containerRect = container.getBoundingClientRect();
            const maxWidth = containerRect.width - 40;
            const maxHeight = containerRect.height - 40;
            const scaleX = maxWidth / this.imageNaturalWidth;
            const scaleY = maxHeight / this.imageNaturalHeight;
            this.scale = Math.min(scaleX, scaleY, 1);

            this.translateX = (containerRect.width - this.imageNaturalWidth * this.scale) / 2;
            this.translateY = (containerRect.height - this.imageNaturalHeight * this.scale) / 2;
            this.updateTransform();
        },
        handleWheel(event) {
            event.preventDefault();
            const container = this.$refs.canvasContainer;
            const rect = container.getBoundingClientRect();
            const mouseX = event.clientX - rect.left;
            const mouseY = event.clientY - rect.top;

            const canvasMouseX = (mouseX - this.translateX) / this.scale;
            const canvasMouseY = (mouseY - this.translateY) / this.scale;

            const delta = event.deltaY > 0 ? 0.9 : 1.1;
            const newScale = Math.max(0.1, Math.min(this.scale * delta, 5));

            this.translateX = mouseX - canvasMouseX * newScale;
            this.translateY = mouseY - canvasMouseY * newScale;
            this.scale = newScale;

            this.updateTransform();
        },
        handleCanvasMouseDown(event) {
            // 中键拖拽
            if (event.button === 1) {
                event.preventDefault()
                this.isDragging = true
                this.startX = event.clientX - this.translateX
                this.startY = event.clientY - this.translateY
                return
            }
            
            // 左键绘制（只在画布上）
            if (event.button === 0 && event.target === this.canvas) {
                this.startDrawing(event)
            }
        },
        handleCanvasMouseMove(event) {
            // 中键拖拽
            if (this.isDragging) {
                this.translateX = event.clientX - this.startX
                this.translateY = event.clientY - this.startY
                this.updateTransform()
                return
            }
            
            // 左键绘制
            if (this.drawing) {
                this.draw(event)
            } else {
                // 更新预览位置
                this.updateBrushPreview(event)
            }
        },
        handleCanvasMouseUp() {
            // 停止拖拽
            this.isDragging = false
            
            // 停止绘制
            if (this.drawing) {
                this.stopDrawing()
            }
            
            // 清除预览
            this.clearBrushPreview()
        },
        handleCanvasMouseLeave() {
            // 停止拖拽
            this.isDragging = false
            
            // 停止绘制
            if (this.drawing) {
                this.stopDrawing()
            }
            
            // 清除预览
            this.clearBrushPreview()
        },
        updateTransform() {
            const wrapper = this.$refs.canvasWrapper
            if (wrapper) {
                wrapper.style.transform = `translate(${this.translateX}px, ${this.translateY}px) scale(${this.scale})`
                this.updateCursor();
            }
        },
        getCanvasCoordinates(event) {
            const rect = this.canvas.getBoundingClientRect();
            const scaleX = this.canvas.width / rect.width;
            const scaleY = this.canvas.height / rect.height;
            const x = (event.clientX - rect.left) * scaleX;
            const y = (event.clientY - rect.top) * scaleY;
            return { x, y };
        },
        updateBrushPreview(event) {
            if (!this.showBrushPreview || !this.previewCtx || this.drawing) return;
            
            const { x, y } = this.getCanvasCoordinates(event);
            this.previewX = x;
            this.previewY = y;
            
            // 清除预览画布
            this.previewCtx.clearRect(0, 0, this.previewCanvas.width, this.previewCanvas.height);
            
            // 绘制预览圆圈
            this.previewCtx.beginPath();
            this.previewCtx.arc(x, y, this.brushSize / 2, 0, Math.PI * 2);
            this.previewCtx.strokeStyle = 'rgba(79, 150, 255, 0.8)';
            this.previewCtx.lineWidth = 2;
            this.previewCtx.stroke();
            
            // 填充半透明圆圈
            this.previewCtx.beginPath();
            this.previewCtx.arc(x, y, this.brushSize / 2, 0, Math.PI * 2);
            this.previewCtx.fillStyle = 'rgba(79, 150, 255, 0.2)';
            this.previewCtx.fill();
            
            // 添加中心点
            this.previewCtx.beginPath();
            this.previewCtx.arc(x, y, 1, 0, Math.PI * 2);
            this.previewCtx.fillStyle = 'rgba(79, 150, 255, 0.9)';
            this.previewCtx.fill();
        },
        clearBrushPreview() {
            if (this.previewCtx) {
                this.previewCtx.clearRect(0, 0, this.previewCanvas.width, this.previewCanvas.height);
            }
        },
    }
}
</script>

<style scoped>
/* Font Awesome 图标样式 */
.upload-icon {
    font-size: 4rem;
    color: #4f96ff;
    margin-bottom: 1rem;
}

.upload-icon svg {
    width: 4rem;
    height: 4rem;
}

/* 基础样式重置 */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

html, body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
                'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
                sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

/* 主容器 */
.app-container {
    position: relative;
    width: 100%;
    min-height: 100vh;
    z-index: 1;  /* 添加较低的 z-index */
}

/* 主内容 */
.main-content {
    position: relative;
    z-index: 1;  /* 添加较低的 z-index */
}

/* 主页面 */
.homepage {
    background: #ffffff;
    padding-bottom: 2rem;
}

/* 头部标题区域 */
.header-section {
    text-align: center;
    padding: 4rem 2rem 2rem;
    background: #ffffff;
}

.main-title {
    font-size: 2.5rem;
    font-weight: 700;
    color: #1a1a1a;
    margin: 0 0 1rem 0;
    line-height: 1.2;
}

.main-subtitle {
    font-size: 1.125rem;
    color: #666666;
    margin: 0;
    max-width: 600px;
    margin-left: auto;
    margin-right: auto;
    line-height: 1.5;
}

/* 主要内容区域 */
.main-section {
    display: flex;
    align-items: flex-start;
    gap: 4rem;
    padding: 2rem 4rem;
    max-width: 1400px;
    margin: 0 auto;
}

/* 左侧演示视频 */
.demo-section {
    flex: 1;
    max-width: 600px;
}

.demo-video {
    position: relative;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 30px 80px rgba(0, 0, 0, 0.25), 0 10px 30px rgba(0, 0, 0, 0.15);
    background: #f8f9fa;
    aspect-ratio: 16/9;
}

.demo-video-player {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 20px;
    background: #000;
}



.demo-description {
    text-align: center;
    margin-top: 1.5rem;
}

.demo-description h3 {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1a1a1a;
    margin: 0 0 0.5rem 0;
}

.demo-description p {
    font-size: 1rem;
    color: #666666;
    margin: 0;
}

/* 右侧上传区域 */
.upload-section {
    flex: 1;
    max-width: 500px;
    display: flex;
    align-items: flex-start;
    min-height: 400px;
}

.upload-container {
    width: 100%;
}

.upload-box {
    background: #f8f9fa;
    border: 2px dashed #d0d7de;
    border-radius: 20px;
    padding: 3rem 2rem;
    text-align: center;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
}

.upload-box:hover {
    border-color: #4f96ff;
    background: #f5f8ff;
    transform: translateY(-2px);
    box-shadow: 0 8px 30px rgba(79, 150, 255, 0.15);
}

.upload-input {
    display: none;
}

.upload-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1.5rem;
}

.upload-icon {
    font-size: 4rem;
    color: #4f96ff;
    margin-bottom: 1rem;
}

.upload-title {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1a1a1a;
    margin: 0;
    line-height: 1.4;
}

.upload-description {
    font-size: 0.9rem;
    color: #666666;
    margin: 0;
}

.upload-buttons {
    display: flex;
    gap: 1rem;
    margin-top: 1rem;
}

.btn-upload-primary {
    background: #4f96ff;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 12px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.btn-upload-primary:hover {
    background: #3574d6;
    transform: translateY(-1px);
}

.btn-upload-secondary {
    background: white;
    color: #4f96ff;
    border: 2px solid #4f96ff;
    padding: 0.75rem 1.5rem;
    border-radius: 12px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.btn-upload-secondary:hover {
    background: #4f96ff;
    color: white;
    transform: translateY(-1px);
}



/* 工作区 */
.workspace {
    min-height: 100vh;
    display: flex;
    gap: 1rem;
    padding: 1rem;
    background: #ffffff;
}

/* 左侧工具栏 */
.left-sidebar {
    width: 280px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border-radius: 15px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    overflow-y: auto;
}

.tool-section {
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    padding-bottom: 1.5rem;
}

.tool-section:last-child {
    border-bottom: none;
    padding-bottom: 0;
}

.section-title {
    font-size: 1rem;
    font-weight: 600;
    color: #2c3e50;
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.tool-group {
    margin-bottom: 1rem;
}

.tool-group:last-child {
    margin-bottom: 0;
}

.tool-item {
    display: block;
    margin-bottom: 0.75rem;
}

.tool-label {
    display: block;
    font-size: 0.875rem;
    font-weight: 500;
    color: #4a5568;
    margin-bottom: 0.5rem;
}

.brush-control {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: #f8fafc;
    padding: 0.75rem;
    border-radius: 8px;
}

.brush-slider {
    flex: 1;
    height: 6px;
    background: #e2e8f0;
    outline: none;
    border-radius: 3px;
    cursor: pointer;
}

.brush-slider::-webkit-slider-thumb {
    appearance: none;
    width: 18px;
    height: 18px;
    background: #667eea;
    border-radius: 50%;
    cursor: pointer;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
}

.brush-value {
    font-size: 0.75rem;
    font-weight: 600;
    color: #667eea;
    min-width: 45px;
    text-align: center;
    padding: 0.25rem 0.5rem;
    background: rgba(102, 126, 234, 0.1);
    border-radius: 12px;
}

.zoom-controls-sidebar {
    background: #f8fafc;
    padding: 0.75rem;
    border-radius: 8px;
}

.zoom-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.75rem;
}

.zoom-label {
    font-size: 0.875rem;
    color: #4a5568;
}

.zoom-value {
    font-size: 0.875rem;
    font-weight: 600;
    color: #667eea;
}

.zoom-buttons {
    display: flex;
    gap: 0.5rem;
    justify-content: space-between;
}

.btn-zoom {
    flex: 1;
    padding: 0.5rem;
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    color: #4a5568;
    transition: all 0.2s ease;
}

.btn-zoom:hover {
    background: #667eea;
    color: white;
    border-color: #667eea;
}

.action-section {
}

.tip-card {
    background: linear-gradient(135deg, #667eea, #764ba2);
    color: white;
    padding: 1.25rem;
    border-radius: 12px;
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    font-size: 0.875rem;
    line-height: 1.5;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.2);
}

.action-buttons {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
}

.btn-full {
    width: 100%;
    justify-content: center;
}

.btn-large {
    padding: 1rem 1.5rem;
    font-size: 0.9rem;
    font-weight: 600;
}

/* 画布区域 */
.canvas-section {
    flex: 1;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border-radius: 15px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    display: flex;
    flex-direction: column;
}

.canvas-container {
    flex: 1;
    position: relative;
    overflow: hidden;
    background: 
        radial-gradient(circle at 25% 25%, #f0f0f0 1px, transparent 1px),
        radial-gradient(circle at 75% 75%, #f0f0f0 1px, transparent 1px);
    background-size: 20px 20px;
    min-height: 500px;
    max-height: 870px;
}

.canvas-wrapper {
    transform-origin: top left;
    transition: transform 0.1s ease;
    position: relative;
}

.display-image {
    display: block;
    max-width: none;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.drawing-canvas {
    position: absolute;
    top: 0;
    left: 0;
    border-radius: 8px;
    background: transparent;
    pointer-events: auto;
}



/* 按钮样式 */
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    font-size: 0.875rem;
    font-weight: 600;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    text-decoration: none;
    white-space: nowrap;
}

.btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.btn-primary {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(102, 126, 234, 0.5);
}

.btn-secondary {
    background: #f7fafc;
    color: #4a5568;
    border: 1px solid #e2e8f0;
}

.btn-secondary:hover {
    background: #edf2f7;
    border-color: #cbd5e0;
}

.btn-success {
    background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
    color: white;
    box-shadow: 0 4px 12px rgba(72, 187, 120, 0.4);
}

.btn-success:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(72, 187, 120, 0.5);
}

.btn-outline {
    background: transparent;
    color: #667eea;
    border: 2px solid #667eea;
}

.btn-outline:hover {
    background: #667eea;
    color: white;
}

/* 加载遮罩 */
.loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(5px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
}

.loading-content {
    text-align: center;
    color: white;
}

.loading-spinner {
    width: 60px;
    height: 60px;
    border: 4px solid rgba(255, 255, 255, 0.3);
    border-top: 4px solid white;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.loading-content h3 {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 0.5rem;
}

.loading-content p {
    font-size: 0.875rem;
    opacity: 0.8;
}

/* 响应式设计 */
@media (max-width: 1024px) {
    .header-section {
        padding: 3rem 2rem 1.5rem;
    }
    
    .main-title {
        font-size: 2rem;
    }
    
    .main-section {
        flex-direction: column;
        gap: 3rem;
        padding: 2rem;
        align-items: center;
    }
    
    .demo-section {
        max-width: 100%;
    }
    
    .upload-section {
        max-width: 100%;
        min-height: auto;
    }
    

    
    .workspace {
        flex-direction: column;
        gap: 1rem;
        min-height: auto;
    }
    
    .left-sidebar {
        width: 100%;
        order: 2;
        max-height: none;
        overflow-y: visible;
    }
    
    .canvas-section {
        order: 1;
        min-height: 400px;
    }
    
    .tool-section {
        padding-bottom: 1rem;
    }
    
    .action-buttons {
        flex-direction: row;
        gap: 1rem;
    }
}

@media (max-width: 768px) {
    .header-section {
        padding: 2rem 1rem 1rem;
    }
    
    .main-title {
        font-size: 1.75rem;
    }
    
    .main-subtitle {
        font-size: 1rem;
    }
    
    .main-section {
        padding: 1rem;
        gap: 2rem;
        align-items: center;
    }
    
    .upload-box {
        padding: 2rem 1.5rem;
    }
    
    .upload-buttons {
        flex-direction: column;
        gap: 0.75rem;
    }
    
    .btn-upload-primary,
    .btn-upload-secondary {
        justify-content: center;
    }
    

    
    .workspace {
        padding: 0.5rem;
        min-height: auto;
    }
    
    .left-sidebar {
        padding: 1rem;
        max-height: none;
    }
    
    .section-title {
        font-size: 0.9rem;
    }
    
    .action-buttons {
        flex-direction: column;
        gap: 0.75rem;
    }
    
    .btn-large {
        padding: 0.875rem 1rem;
        font-size: 0.875rem;
    }
    
    .canvas-section {
        min-height: 400px;
    }
}

/* 动画效果 */

@keyframes fadeIn {
    from { opacity: 0; transform: translateY(20px); }
    to { opacity: 1; transform: translateY(0); }
}

.upload-section, .workspace {
    animation: fadeIn 0.5s ease-out;
}
</style>
