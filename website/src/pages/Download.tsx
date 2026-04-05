import { useEffect, useMemo, useState } from 'react';
import { motion } from 'motion/react';
import {
  TabletSmartphone,
  Monitor,
  Terminal,
  Download as DownloadIcon,
  LoaderCircle,
} from 'lucide-react';

type PlatformKey = 'macos' | 'android' | 'ipad' | 'windows' | 'linux';

type PlatformCard = {
  key: PlatformKey;
  title: string;
  description: string;
  colSpan: string;
  icon: 'apple' | 'android' | 'windows' | 'linux';
};

const PLAN_TEXT = '已在开发计划，尽情期待';
const DEFAULT_BACKEND_ROOT = 'https://apidonut.cruty.cn';

const PLATFORM_CARDS: PlatformCard[] = [
  {
    key: 'macos',
    title: 'macOS',
    description: '支持 Apple Silicon 与 Intel 芯片',
    colSpan: 'xl:col-span-3',
    icon: 'apple',
  },
  {
    key: 'android',
    title: '安卓',
    description: '适用于安卓手机与平板设备',
    colSpan: 'xl:col-span-3',
    icon: 'android',
  },
  {
    key: 'ipad',
    title: 'iPad',
    description: '面向 iPad 大屏阅读体验',
    colSpan: 'xl:col-span-2',
    icon: 'apple',
  },
  {
    key: 'windows',
    title: 'Windows',
    description: '桌面版本',
    colSpan: 'xl:col-span-2',
    icon: 'windows',
  },
  {
    key: 'linux',
    title: 'Linux',
    description: '桌面版本',
    colSpan: 'xl:col-span-2',
    icon: 'linux',
  },
];

type RosemaryPublicConfig = {
  enabled: boolean;
  apiBaseUrl: string;
  appName: string;
  resVersion: number;
};

type UpdateCheckResponse = {
  appUpgrade?: boolean;
  appUpgradeUrl?: string;
  appUpgradePlatform?: string;
};

function normalizeBaseUrl(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T | null> {
  try {
    const response = await fetch(url, init);
    if (!response.ok) return null;
    return (await response.json()) as T;
  } catch (_) {
    return null;
  }
}

async function fetchRosemaryConfig(): Promise<RosemaryPublicConfig | null> {
  const backendRoot = normalizeBaseUrl(
    (import.meta as ImportMeta & { env?: Record<string, string> }).env
      ?.VITE_DONUT_BACKEND_BASE_URL || DEFAULT_BACKEND_ROOT,
  );
  const config = await fetchJson<RosemaryPublicConfig>(`${backendRoot}/config/rosemary`, {
    method: 'GET',
    cache: 'no-store',
  });
  if (!config) return null;
  if (!config.enabled) return null;
  if (!config.apiBaseUrl?.trim() || !config.appName?.trim()) return null;
  return config;
}

async function postUpdateCheck(
  config: RosemaryPublicConfig,
  platform: string,
): Promise<UpdateCheckResponse | null> {
  const url = `${normalizeBaseUrl(config.apiBaseUrl)}/update`;
  return fetchJson<UpdateCheckResponse>(url, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      appName: config.appName,
      appPasswd: '',
      appVersion: 0,
      betaPasswd: '',
      resVersion: config.resVersion || 0,
      platform,
    }),
  });
}

function toRosemaryPlatform(platform: PlatformKey): string {
  if (platform === 'ipad') return 'ios';
  return platform;
}

function urlLooksLikePlatform(url: string, platform: PlatformKey): boolean {
  const normalized = url.toLowerCase();
  if (platform === 'macos') {
    return normalized.endsWith('.dmg') || normalized.includes('mac');
  }
  if (platform === 'android') {
    return normalized.endsWith('.apk') || normalized.includes('android') || normalized.includes('pad');
  }
  if (platform === 'ipad') {
    return normalized.endsWith('.ipa') || normalized.includes('ios') || normalized.includes('ipad');
  }
  if (platform === 'windows') {
    return (
      normalized.endsWith('.exe') ||
      normalized.endsWith('.msi') ||
      normalized.includes('windows') ||
      normalized.includes('win')
    );
  }
  return (
    normalized.endsWith('.appimage') ||
    normalized.endsWith('.deb') ||
    normalized.endsWith('.rpm') ||
    normalized.includes('linux')
  );
}

async function resolvePlatformDownloadUrlFromRosemary(
  config: RosemaryPublicConfig,
  platform: PlatformKey,
): Promise<string | null> {
  const result = await postUpdateCheck(config, toRosemaryPlatform(platform));
  if (!result?.appUpgrade) return null;
  const url = result.appUpgradeUrl?.trim();
  if (!url) return null;
  if (!urlLooksLikePlatform(url, platform)) {
    const responsePlatform = (result.appUpgradePlatform || '').toLowerCase().trim();
    if (responsePlatform && responsePlatform !== toRosemaryPlatform(platform)) {
      return null;
    }
  }
  return url;
}

export default function Download() {
  const appleLogoLightUrl = 'https://tianyue.s3.bitiful.net/logo/Apple_logo_black.svg';
  const appleLogoDarkUrl = 'https://tianyue.s3.bitiful.net/logo/Apple_logo_white.svg.png';
  const [loading, setLoading] = useState(true);
  const [downloadLinks, setDownloadLinks] = useState<Record<PlatformKey, string | null>>({
    macos: null,
    android: null,
    ipad: null,
    windows: null,
    linux: null,
  });

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      const rosemaryConfig = await fetchRosemaryConfig();
      if (!rosemaryConfig) {
        setLoading(false);
        return;
      }
      const pairs = await Promise.all(PLATFORM_CARDS.map(async (platform) => {
        const url = await resolvePlatformDownloadUrlFromRosemary(
          rosemaryConfig,
          platform.key,
        );
        return [platform.key, url] as const;
      }));
      if (cancelled) return;
      setDownloadLinks(Object.fromEntries(pairs) as Record<PlatformKey, string | null>);
      setLoading(false);
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const versionDateText = useMemo(() => {
    const now = new Date();
    return now.toISOString().slice(0, 10);
  }, []);

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: { staggerChildren: 0.1 }
    }
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.5 } }
  };

  return (
    <div className="min-h-[calc(100vh-56px)] py-24 px-4 sm:px-6 max-w-7xl mx-auto">
      <motion.div 
        initial="hidden"
        animate="visible"
        variants={containerVariants}
        className="text-center mb-20"
      >
        <motion.h1 variants={itemVariants} className="text-5xl md:text-6xl font-normal tracking-normal text-[#201A19] dark:text-[#EDE0DE] mb-6">
          获取 Donut
        </motion.h1>
        <motion.p variants={itemVariants} className="text-xl text-[#534341] dark:text-[#D8C2BF] max-w-2xl mx-auto tracking-normal">
          选择适合您操作系统的版本，即刻开启全新的阅读体验。
        </motion.p>
      </motion.div>

      <motion.div 
        initial="hidden"
        animate="visible"
        variants={containerVariants}
        className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-6 gap-6 max-w-6xl mx-auto"
      >
        {PLATFORM_CARDS.map((platform) => {
          const downloadUrl = downloadLinks[platform.key];
          const showDownload = Boolean(downloadUrl);
          return (
            <motion.div
              key={platform.key}
              variants={itemVariants}
              className={`bg-[#FCEAE7] dark:bg-[#271A18] p-10 rounded-[28px] flex flex-col items-center text-center group transition-colors duration-300 ${platform.colSpan}`}
            >
              <div className="w-20 h-20 bg-[#FFF8F7] dark:bg-[#1A1110] rounded-full flex items-center justify-center text-[#201A19] dark:text-[#EDE0DE] mb-8 shadow-sm group-hover:scale-105 transition-transform duration-300">
                {platform.icon === 'apple' ? (
                  <>
                    <img
                      src={appleLogoLightUrl}
                      alt="Apple logo"
                      className="w-10 h-10 object-contain dark:hidden"
                    />
                    <img
                      src={appleLogoDarkUrl}
                      alt="Apple logo"
                      className="hidden w-10 h-10 object-contain dark:block"
                    />
                  </>
                ) : platform.icon === 'android' ? (
                  <TabletSmartphone size={40} />
                ) : platform.icon === 'windows' ? (
                  <Monitor size={40} />
                ) : (
                  <Terminal size={40} />
                )}
              </div>
              <h3 className="text-3xl font-medium text-[#201A19] dark:text-[#EDE0DE] mb-2 tracking-normal">
                {platform.title}
              </h3>
              <p className="text-[#534341] dark:text-[#D8C2BF] text-sm mb-8">
                {platform.description}
              </p>
              {loading ? (
                <button
                  className="mt-auto w-full bg-[#FFDAD4] dark:bg-[#6E2424] text-[#3A0909] dark:text-[#FFDAD4] py-3.5 rounded-full font-medium transition-colors flex items-center justify-center gap-2 shadow-sm cursor-default"
                >
                  <LoaderCircle size={18} className="animate-spin" />
                  正在获取最新下载地址
                </button>
              ) : showDownload ? (
                <a
                  href={downloadUrl!}
                  className="mt-auto w-full bg-[#8C3B3B] dark:bg-[#E0AFA0] text-white dark:text-[#4A1919] py-3.5 rounded-full font-medium hover:bg-[#8C3B3B]/90 dark:hover:bg-[#E0AFA0]/90 transition-colors flex items-center justify-center gap-2 shadow-sm active:scale-95"
                >
                  <DownloadIcon size={18} />
                  下载
                </a>
              ) : (
                <button
                  className="mt-auto w-full bg-[#FFDAD4] dark:bg-[#6E2424] text-[#3A0909] dark:text-[#FFDAD4] py-3.5 rounded-full font-medium transition-colors flex items-center justify-center gap-2 shadow-sm cursor-default"
                >
                  {PLAN_TEXT}
                </button>
              )}
            </motion.div>
          );
        })}
      </motion.div>

      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.6 }}
        className="mt-24 text-center"
      >
        <p className="text-[#534341] dark:text-[#D8C2BF] text-sm mb-4">
          下载地址会自动同步最新发布包 | 最近检查日期：{versionDateText}
        </p>
      </motion.div>
    </div>
  );
}
