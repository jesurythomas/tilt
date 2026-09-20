// =========================================================================
// GyroscopeController.ts - DeviceOrientation Gyro & Accelerometer Tilt Input
// =========================================================================

import { Point2D } from './Types';

export class GyroscopeController {
  public isSupported: boolean = false;
  public isListening: boolean = false;
  public permissionState: 'unknown' | 'granted' | 'denied' = 'unknown';

  // Raw sensor readings
  private rawBeta: number = 0;
  private rawGamma: number = 0;
  private hasReceivedData: boolean = false;

  // Calibrated neutral resting angle
  public calibratedBeta: number = 38; // Default ~38 degree resting phone tilt
  public calibratedGamma: number = 0;

  // Output vector normalized to [-1, 1]
  public tiltVector: Point2D = { x: 0, y: 0 };

  private onCalibratedCallback?: (beta: number, gamma: number) => void;

  constructor() {
    this.checkSupport();
    this.loadCalibration();
  }

  private checkSupport() {
    if (typeof window !== 'undefined' && 'DeviceOrientationEvent' in window) {
      this.isSupported = true;
    }
  }

  private loadCalibration() {
    try {
      const saved = localStorage.getItem('tilt_gyro_calibration');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (typeof parsed.beta === 'number') this.calibratedBeta = parsed.beta;
        if (typeof parsed.gamma === 'number') this.calibratedGamma = parsed.gamma;
      }
    } catch {}
  }

  public saveCalibration() {
    try {
      localStorage.setItem('tilt_gyro_calibration', JSON.stringify({
        beta: this.calibratedBeta,
        gamma: this.calibratedGamma
      }));
    } catch {}
  }

  /**
   * Request motion permission (Required for iOS 13+ Safari) and start listening
   */
  public async requestPermissionAndStart(): Promise<boolean> {
    if (!this.isSupported) {
      console.warn('DeviceOrientationEvent not supported on this browser/platform');
      return false;
    }

    if (
      typeof (window as any).DeviceOrientationEvent !== 'undefined' &&
      typeof (window as any).DeviceOrientationEvent.requestPermission === 'function'
    ) {
      try {
        const res = await (window as any).DeviceOrientationEvent.requestPermission();
        if (res === 'granted') {
          this.permissionState = 'granted';
          this.startListening();
          return true;
        } else {
          this.permissionState = 'denied';
          return false;
        }
      } catch (err) {
        console.error('DeviceOrientation permission error:', err);
        this.permissionState = 'denied';
        return false;
      }
    } else {
      // Android / Chrome / non-permission browsers
      this.permissionState = 'granted';
      this.startListening();
      return true;
    }
  }

  public startListening() {
    if (this.isListening) return;
    window.addEventListener('deviceorientation', this.handleOrientation, true);
    this.isListening = true;
  }

  public stopListening() {
    if (!this.isListening) return;
    window.removeEventListener('deviceorientation', this.handleOrientation, true);
    this.isListening = false;
    this.tiltVector = { x: 0, y: 0 };
  }

  /**
   * Calibrates current orientation as the neutral resting zero position
   */
  public calibrateCurrentPosition() {
    if (this.hasReceivedData) {
      this.calibratedBeta = this.rawBeta;
      this.calibratedGamma = this.rawGamma;
    } else {
      // Set to comfortable default if sensor hasn't reported yet
      this.calibratedBeta = 38;
      this.calibratedGamma = 0;
    }
    this.saveCalibration();
    if (this.onCalibratedCallback) {
      this.onCalibratedCallback(this.calibratedBeta, this.calibratedGamma);
    }
    this.tiltVector = { x: 0, y: 0 };
  }

  public setOnCalibrated(cb: (beta: number, gamma: number) => void) {
    this.onCalibratedCallback = cb;
  }

  public hasSensorData(): boolean {
    return this.hasReceivedData;
  }

  private handleOrientation = (e: DeviceOrientationEvent) => {
    if (e.beta === null || e.gamma === null) return;
    this.hasReceivedData = true;
    this.rawBeta = e.beta;
    this.rawGamma = e.gamma;

    // Detect screen orientation
    let screenAngle = 0;
    if (typeof window !== 'undefined') {
      if (screen && screen.orientation && typeof screen.orientation.angle === 'number') {
        screenAngle = screen.orientation.angle;
      } else if (typeof (window as any).orientation === 'number') {
        screenAngle = (window as any).orientation;
      }
    }

    // Map axes based on orientation angle
    let roll = 0;
    let pitch = 0;

    if (screenAngle === 90) {
      // Landscape left
      roll = e.beta - this.calibratedBeta;
      pitch = -(e.gamma - this.calibratedGamma);
    } else if (screenAngle === -90 || screenAngle === 270) {
      // Landscape right
      roll = -(e.beta - this.calibratedBeta);
      pitch = e.gamma - this.calibratedGamma;
    } else if (screenAngle === 180) {
      // Inverted portrait
      roll = -(e.gamma - this.calibratedGamma);
      pitch = -(e.beta - this.calibratedBeta);
    } else {
      // Standard Portrait (0)
      roll = e.gamma - this.calibratedGamma;
      pitch = e.beta - this.calibratedBeta;
    }

    // Max tilt angle for full deflection (24 degrees)
    const maxTiltAngle = 24;
    let vx = Math.max(-1, Math.min(1, roll / maxTiltAngle));
    let vy = Math.max(-1, Math.min(1, pitch / maxTiltAngle));

    // Deadzone (7% neutral deadzone for steady resting hands)
    const mag = Math.sqrt(vx * vx + vy * vy);
    const deadzoneThreshold = 0.07;

    if (mag < deadzoneThreshold) {
      this.tiltVector = { x: 0, y: 0 };
    } else {
      const scaledMag = (mag - deadzoneThreshold) / (1 - deadzoneThreshold);
      this.tiltVector = {
        x: (vx / mag) * scaledMag,
        y: (vy / mag) * scaledMag
      };
    }
  };
}
