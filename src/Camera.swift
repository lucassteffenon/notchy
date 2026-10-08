import AVFoundation
import SwiftUI

/// Sessão da webcam; só liga pelo botão e desliga ao sair da tela.
final class CameraController: ObservableObject {
    enum Status { case idle, starting, running, denied, noCamera }

    let session = AVCaptureSession()
    @Published var status: Status = .idle
    private let queue = DispatchQueue(label: "notchy.camera")
    private var configured = false
    private var errorObserver: NSObjectProtocol?

    /// Uma única camada de preview, reaproveitada sempre que o notch abre. Criar uma nova
    /// camada para a mesma sessão a cada abertura deixava a imagem preta da segunda vez em diante.
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.transform = CATransform3DMakeScale(-1, 1, 1) // espelhado, como um espelho de verdade
        return layer
    }()

    init() {
        // Se a câmera der erro (ex.: outro app pegou ela), tenta religar
        errorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main
        ) { [weak self] _ in
            guard let self, self.status == .running else { return }
            self.queue.async { self.session.startRunning() }
        }
    }

    deinit {
        if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.run() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
        if status == .running || status == .starting { status = .idle }
    }

    private func run() {
        status = .starting
        queue.async {
            if !self.configured {
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.status = .noCamera }
                    return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                self.session.addInput(input)
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                // Se desligaram enquanto ligava, não volta a mostrar como ligada
                if self.status == .starting { self.status = .running }
            }
        }
    }
}

/// Mostra a camada de preview do controlador (sempre a mesma).
final class CameraPreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(previewLayer) // tira a camada de onde ela estava antes
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não suportado") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.bounds = bounds
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    /// Solta a camada, a menos que outra view já tenha pegado ela.
    func detach() {
        if previewLayer.superlayer === layer { previewLayer.removeFromSuperlayer() }
    }
}

struct CameraPreview: NSViewRepresentable {
    let camera: CameraController

    func makeNSView(context: Context) -> CameraPreviewNSView {
        CameraPreviewNSView(previewLayer: camera.previewLayer)
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.detach()
    }
}

/// Caixa da câmera com botão de ligar/desligar. Desliga sozinha ao sair da tela.
struct CameraBox: View {
    @ObservedObject var camera: CameraController
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07))
            switch camera.status {
            case .running:
                CameraPreview(camera: camera)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomTrailing) {
                        Button { camera.stop() } label: {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: compact ? 11 : 13))
                                .padding(compact ? 6 : 8)
                                .background(Color.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help("Desligar câmera")
                    }
            case .starting:
                ProgressView().controlSize(.small)
            case .idle:
                Button { camera.start() } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "video.fill").font(.system(size: compact ? 22 : 30))
                        Text("Ligar câmera").font(compact ? .caption : .callout)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
            case .denied:
                Text(compact ? "Sem acesso à câmera"
                             : "Permita a câmera em Ajustes → Privacidade e Segurança → Câmera")
                    .font(compact ? .caption : .callout)
                    .multilineTextAlignment(.center)
                    .padding()
            case .noCamera:
                Text("Nenhuma câmera encontrada").font(compact ? .caption : .callout)
            }
        }
        .onDisappear { camera.stop() }
    }
}
