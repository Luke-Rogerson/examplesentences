'use client';

import type React from 'react';

import { Search } from 'lucide-react';
import { useState } from 'react';

import { ThemeToggle } from './components/theme-toggle';
import { Button } from './components/ui/button';
import { Card, CardContent } from './components/ui/card';
import { Input } from './components/ui/input';
import { Skeleton } from './components/ui/skeleton';

type Response = {
  message: string;
  language: string;
  sentences: {
    target: string;
    english: string;
    pronunciation: string;
  }[];
};

const API_URL = import.meta.env.VITE_API_URL;
const API_KEY = import.meta.env.VITE_API_KEY;

export default function App() {
  const [examples, setExamples] = useState<
    {
      target: string;
      english: string;
      pronunciation: string;
    }[]
  >([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [detectedLanguage, setDetectedLanguage] = useState('');
  const [copied, setCopied] = useState(false);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!searchTerm.trim()) return;

    setLoading(true);
    setError('');
    setExamples([]);
    setDetectedLanguage('');

    try {
      const response = await fetch(
        `${API_URL}/${encodeURIComponent(searchTerm)}`,
        {
          headers: {
            // This is only needed as I wanted to enforce a global daily quota and this is the easiest way to do it in API Gateway. API key is not really a secret.
            'x-api-key': API_KEY,
          },
        }
      );

      const data: Response = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Failed to fetch examples');
      }

      setExamples(data.sentences);
      setDetectedLanguage(data.language);
    } catch (err) {
      console.log('--------------------------------');
      console.log('err :', err);
      console.log('--------------------------------');
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unexpected error occurred. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  // Function to copy all examples to clipboard
  const copyAllToClipboard = () => {
    if (examples.length === 0) return;

    const textToCopy = examples
      .map(
        (example) =>
          `${example.target}\n${example.pronunciation}\n${example.english}\n`
      )
      .join('\n');

    navigator.clipboard
      .writeText(textToCopy)
      .then(() => {
        setCopied(true);
        // Reset the copied state after 2 seconds
        setTimeout(() => setCopied(false), 2000);
      })
      .catch((err) => {
        console.error('Failed to copy text: ', err);
        setError('Failed to copy to clipboard');
      });
  };

  return (
    <main className="container mx-auto px-4 py-12 max-w-4xl">
      <div className="space-y-8">
        <div className="space-y-2 text-center relative">
          <div className="absolute right-0 top-0">
            <ThemeToggle />
          </div>
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Example Sentences
          </h1>
          <p className="text-muted-foreground">
            Enter a word or phrase in any language to see usage examples
          </p>
        </div>

        <form
          onSubmit={handleSearch}
          className="flex w-full max-w-lg mx-auto items-center space-x-2"
        >
          <Input
            type="text"
            placeholder="Enter a word or phrase..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1"
          />
          <Button type="submit" disabled={loading}>
            {loading ? (
              <span className="flex items-center gap-1">
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                <span>Loading</span>
              </span>
            ) : (
              <span className="flex items-center gap-1">
                <Search className="h-4 w-4" />
                <span>Search</span>
              </span>
            )}
          </Button>
        </form>

        {error && (
          <div
            className="text-center p-4 bg-destructive/10 border border-destructive rounded-md animate-fadeIn"
            style={{ animationDelay: '0ms' }}
          >
            <p className="text-destructive font-medium">{error}</p>
          </div>
        )}

        {/* Skeleton loaders while loading */}
        {loading && (
          <div className="space-y-4">
            <h2 className="text-xl font-semibold text-center">
              Loading examples...
            </h2>
            <div className="grid gap-4">
              {[...Array(5)].map((_, index) => (
                <Card key={`skeleton-${index}`} className="overflow-hidden">
                  <CardContent className="p-4 space-y-2">
                    <Skeleton className="h-6 w-full" />
                    <Skeleton className="h-4 w-3/4" />
                    <div className="pt-2 border-t">
                      <Skeleton className="h-5 w-full mt-2" />
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}

        {/* Actual examples with staggered animation */}
        {!loading && examples.length > 0 && (
          <div className="space-y-4">
            <h2 className="text-xl font-semibold text-center">
              Examples for "
              <span className="text-primary font-bold">{searchTerm}</span>"
            </h2>
            {detectedLanguage && (
              <div className="flex justify-center">
                <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-primary/10 text-primary border border-primary/20">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="mr-1.5 h-4 w-4"
                  >
                    <path d="m5 8 6 6" />
                    <path d="m4 14 6-6 2-3" />
                    <path d="M2 5h12" />
                    <path d="M7 2h1" />
                    <path d="m22 22-5-5" />
                    <path d="M17 8v1" />
                    <path d="M22 8h-1" />
                    <path d="M8 17h1" />
                    <path d="M8 22v-1" />
                  </svg>
                  Detected: {detectedLanguage}
                </span>
              </div>
            )}
            <div className="flex justify-center">
              <Button
                onClick={copyAllToClipboard}
                variant="outline"
                size="sm"
                className="flex items-center gap-2"
              >
                {copied ? (
                  <>
                    <span>Copied!</span>
                  </>
                ) : (
                  <>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      className="lucide lucide-clipboard"
                    >
                      <rect width="8" height="4" x="8" y="2" rx="1" ry="1" />
                      <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
                    </svg>
                    <span>Copy All</span>
                  </>
                )}
              </Button>
            </div>
            <div className="text-center mt-2">
              <p className="text-xs text-muted-foreground">
                Results are generated by AI and may not be accurate. We are not
                responsible for any content generated from user inputs.
              </p>
            </div>
            <div className="grid gap-4">
              {examples.map((example, index) => (
                <Card
                  key={index}
                  className="animate-fadeIn overflow-hidden"
                  style={{
                    animationDelay: `${index * 150}ms`,
                    opacity: 0,
                    animation: `fadeIn 0.5s ease-out ${index * 150}ms forwards`,
                  }}
                >
                  <CardContent className="p-4 space-y-2">
                    <div className="text-lg font-medium">{example.target}</div>
                    <div className="text-sm text-muted-foreground">
                      {example.pronunciation}
                    </div>
                    <div className="pt-2 border-t">{example.english}</div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
